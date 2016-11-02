# Azure namespace
module Azure
  # Armrest namespace
  module Armrest
    # Base class for managing virtual machines
    class VirtualMachineService < ResourceGroupBasedService
      # Create and return a new VirtualMachineService (VMM) instance. Most
      # methods for a VMM instance will return one or more VirtualMachine
      # instances.
      #
      # This subclass accepts the additional :provider option as well. The
      # default is 'Microsoft.ClassicCompute'. You may need to set this to
      # 'Microsoft.Compute' for your purposes.
      #
      def initialize(configuration, options = {})
        super(configuration, 'virtualMachines', 'Microsoft.Compute', options)
      end

      # Return a list of available VM series (aka sizes, flavors, etc), such
      # as "Basic_A1", though other information is included as well.
      #
      def series(location)
        namespace = 'microsoft.compute'
        version = configuration.provider_default_api_version(namespace, 'locations/vmsizes')

        unless version
          raise ArgumentError, "Unable to find resources for #{namespace}"
        end

        url = url_with_api_version(
          version, @base_url, 'subscriptions', configuration.subscription_id,
          'providers', provider, 'locations', location, 'vmSizes'
        )

        JSON.parse(rest_get(url))['value'].map{ |hash| VirtualMachineSize.new(hash) }
      end

      alias sizes series

      # Captures the +vmname+ and associated disks into a reusable CSM template.
      # The 3rd argument is a hash of options that supports the following keys:
      #
      # * vhdPrefix                - The prefix in the name of the blobs.
      # * destinationContainerName - The name of the container inside which the image will reside.
      # * overwriteVhds            - Boolean that indicates whether or not to overwrite any VHD's
      #                              with the same prefix. The default is false.
      #
      def capture(vmname, options, group = configuration.resource_group)
        vm_operate('capture', vmname, group, options)
      end

      # Stop the VM +vmname+ in +group+ and deallocate the tenant in Fabric.
      #
      def deallocate(vmname, group = configuration.resource_group)
        vm_operate('deallocate', vmname, group)
      end

      # Sets the OSState for the +vmname+ in +group+ to 'Generalized'.
      #
      def generalize(vmname, group = configuration.resource_group)
        vm_operate('generalize', vmname, group)
      end

      # Retrieves the settings of the VM named +vmname+ in resource group
      # +group+, which will default to the same as the name of the VM.
      #
      # By default this method will retrieve the model view. If the +model_view+
      # parameter is false, it will retrieve an instance view. The difference is
      # in the details of the information retrieved.
      #
      def get(vmname, group = configuration.resource_group, model_view = true)
        model_view ? super(vmname, group) : get_instance_view(vmname, group)
      end

      # Convenient wrapper around the get method that retrieves the model view
      # for +vmname+ in resource_group +group+.
      #
      def get_model_view(vmname, group = configuration.resource_group)
        get(vmname, group, true)
      end

      # Convenient wrapper around the get method that retrieves the instance view
      # for +vmname+ in resource_group +group+.
      #
      def get_instance_view(vmname, group = configuration.resource_group)
        raise ArgumentError, "must specify resource group" unless group
        raise ArgumentError, "must specify name of the resource" unless vmname

        url = build_url(group, vmname, 'instanceView')
        response = rest_get(url)
        VirtualMachineInstance.new(response)
      end

      # Restart the VM +vmname+ for the given +group+, which will default
      # to the same as the vmname.
      #
      # This is an asynchronous operation that returns a response object
      # which you can inspect, such as response.code or response.headers.
      #
      def restart(vmname, group = configuration.resource_group)
        vm_operate('restart', vmname, group)
      end

      # Start the VM +vmname+ for the given +group+, which will default
      # to the same as the vmname.
      #
      # This is an asynchronous operation that returns a response object
      # which you can inspect, such as response.code or response.headers.
      #
      def start(vmname, group = configuration.resource_group)
        vm_operate('start', vmname, group)
      end

      # Stop the VM +vmname+ for the given +group+ gracefully. However,
      # a forced shutdown will occur after 15 minutes.
      #
      # This is an asynchronous operation that returns a response object
      # which you can inspect, such as response.code or response.headers.
      #
      def stop(vmname, group = configuration.resource_group)
        vm_operate('powerOff', vmname, group)
      end

      # Delete the VM and associated resources. By default, this will
      # delete the VM, its NIC, the associated IP address, and the
      # image files (.vhd and .status) for the VM.
      #
      # If you want to delete other associated resources, such as any
      # attached disks, the VM's underlying storage account, or associated
      # network security groups you must explicitly specify them as an option.
      #
      # An attempt to delete a resource that cannot be deleted because it's
      # still associated with some other resource will be logged and skipped.
      #
      # If the :verbose option is set to true, then additional messages are
      # sent to your configuration log, or stdout if no log was specified.
      #
      # Note that if all of your related resources are in a self-contained
      # resource group, you do not necessarily need this method. You could
      # just delete the resource group itself, which would automatically
      # delete all of its resources.
      #
      def delete_associated(vmname, vmgroup, options = {})
        options = {
          :network_interfaces      => true,
          :ip_addresses            => true,
          :os_disk                 => true,
          :network_security_groups => false,
          :storage_account         => false,
          :verbose                 => false
        }.merge(options)

        Azure::Armrest::Configuration.log ||= STDOUT if options[:verbose]

        vm = get(vmname, vmgroup)

        delete_and_wait(self, vmname, vmgroup, options)

        # Must delete network interfaces first if you want to delete
        # IP addresses or network security groups.
        if options[:network_interfaces] || options[:ip_addresses] || options[:network_security_groups]
          delete_associated_nics(vm, options)
        end

        if options[:os_disk] || options[:storage_account]
          delete_associated_disk(vm, options)
        end
      end

      def model_class
        VirtualMachineModel
      end

      private

      # Deletes any NIC's associated with the VM, and optionally any public IP addresses
      # and network security groups.
      #
      def delete_associated_nics(vm, options)
        nis = Azure::Armrest::Network::NetworkInterfaceService.new(configuration)
        nics = vm.properties.network_profile.network_interfaces.map(&:id)

        nics.each do |nic_id_string|
          nic = get_associated_resource(nic_id_string)
          delete_and_wait(nis, nic.name, nic.resource_group, options)

          if options[:ip_addresses]
            ips = Azure::Armrest::Network::IpAddressService.new(configuration)
            nic.properties.ip_configurations.each do |ip|
              ip = get_associated_resource(ip.properties.public_ip_address.id)
              delete_and_wait(ips, ip.name, ip.resource_group, options)
            end
          end

          if options[:network_security_groups]
            nsgs = Azure::Armrest::Network::NetworkSecurityGroupService.new(configuration)
            nic.properties.network_security_group
            nsg = get_associated_resource(nic.properties.network_security_group.id)
            delete_and_wait(nsgs, nsg.name, nsg.resource_group, options)
          end
        end
      end

      # This deletes the OS disk from the storage account that's backing the
      # virtual machine, along with the .status file. This does NOT delete
      # copies of the disk.
      #
      # If the option to delete the entire storage account was selected, then
      # it will not bother with deleting invidual files from the storage
      # account first.
      #
      def delete_associated_disk(vm, options)
        uri = Addressable::URI.parse(vm.properties.storage_profile.os_disk.vhd.uri)

        # The uri looks like https://foo123.blob.core.windows.net/vhds/something123.vhd
        storage_acct_name = uri.host.split('.').first     # storage name, e.g. 'foo123'
        storage_acct_disk = File.basename(uri.to_s)       # disk name, e.g. 'something123.vhd'
        storage_acct_path = File.dirname(uri.path)[1..-1] # container, e.g. 'vhds'

        # Must find it this way because the resource group information isn't provided
        sas = Azure::Armrest::StorageAccountService.new(configuration)
        storage_acct_obj  = sas.list_all.find { |s| s.name == storage_acct_name }
        storage_acct_keys = sas.list_account_keys(storage_acct_obj.name, storage_acct_obj.resource_group)

        # Deleting the storage account does not require deleting the disks
        # first, so skip that if deletion of the storage account was requested.
        if options[:storage_account]
          delete_and_wait(sas, storage_acct_obj.name, storage_acct_obj.resource_group, options)
        else
          key = storage_acct_keys['key1'] || storage_acct_keys['key2']

          storage_acct_obj.blobs(storage_acct_path, key).each do |blob|
            extension = File.extname(blob.name)
            next unless ['.vhd', '.status'].include?(extension)

            if blob.name == storage_acct_disk
              if options[:verbose]
                msg = "Deleting blob #{blob.container}/#{blob.name}"
                Azure::Armrest::Configuration.log.info(msg)
              end
              storage_acct_obj.delete_blob(blob.container, blob.name, key)
            end

            if extension == '.status' && blob.name.start_with?(vm.name)
              if options[:verbose]
                msg = "Deleting blob #{blob.container}/#{blob.name}"
                Azure::Armrest::Configuration.log.info(msg)
              end
              storage_acct_obj.delete_blob(blob.container, blob.name, key)
            end
          end
        end
      end

      # Delete a +service+ type resource using its name and resource group,
      # and wait for the operation to complete before returning.
      #
      # If the operation fails because a dependent resource is still attached,
      # then the error is logged (in verbose mode) and ignored.
      #
      def delete_and_wait(service, name, group, options)
        verbose = options[:verbose]

        resource_type = service.class.to_s.sub('Service', '').split('::').last

        if verbose
          msg = "Deleting #{resource_type} #{name}/#{group}"
          Azure::Armrest::Configuration.log.info(msg)
        end

        headers = service.delete(name, group)

        loop do
          status = wait(headers)
          break if status.downcase.start_with?('succ') # Succeeded, Success, etc.
        end

        if verbose
          msg = "Deleted #{resource_type} #{name}/#{group}"
          Azure::Armrest::Configuration.log.info(msg)
        end
      rescue Azure::Armrest::BadRequestException, Azure::Armrest::PreconditionFailedException => err
        msg = "Unable to delete #{resource_type} #{name}/#{group}, skipping. Message: #{err.message}"
        Azure::Armrest::Configuration.log.warn(msg)
      end

      def vm_operate(action, vmname, group, options = {})
        raise ArgumentError, "must specify resource group" unless group
        raise ArgumentError, "must specify name of the vm" unless vmname

        url = build_url(group, vmname, action)
        rest_post(url)
        nil
      end
    end
  end
end
