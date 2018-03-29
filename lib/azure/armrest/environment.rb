module Azure
  module Armrest
    class Environment
      # A list of valid keys that can be passed to the constructor
      VALID_KEYS = [ 
        :name,
        :active_directory_authority,
        :active_directory_resource_id,
        :gallery_url,
        :graph_url,
        :graph_api_version,
        :key_vault_dns_suffix,
        :key_vault_service_resource_id,
        :publish_settings_file_url,
        :resource_manager_url,
        :service_management_url,
        :sql_database_dns_suffix,
        :storage_suffix,
        :traffic_manager_dns_suffix
      ]

      # The Environment name
      attr_reader :name

      # The authority used to acquire an AD token
      attr_reader :active_directory_authority

      # The resource ID used to obtain an AD token
      attr_reader :active_directory_resource_id

      # The template gallery endpoint
      attr_reader :gallery_url

      # The Active Directory resource ID
      attr_reader :graph_url

      # The api-version for Active Directory
      attr_reader :graph_api_version

      # The KeyValut service DNS suffix
      attr_reader :key_vault_dns_suffix

      # The KeyVault service resource ID
      attr_reader :key_vault_service_resource_id

      # The publish settings file URL
      attr_reader :publish_settings_file_url

      # The resource management endpoint
      attr_reader :resource_manager_url

      # The service management URL
      attr_reader :service_management_url

      # The DNS suffix for SQL Server instances
      attr_reader :sql_database_dns_suffix

      # The endpoint suffix for storage accounts
      attr_reader :storage_suffix

      # The DNS suffix for TrafficManager
      attr_reader :traffic_manager_dns_suffix

      # Creates a new Azure::Armrest::Environment object. At a minimum, the
      # options hash must include the :name, :active_directory_authority and
      # :active_directory_resource_id.
      #
      # Note that there are pre-generated environments already for Public
      # and US Government environments.
      #
      def initialize(options)
        options.symbolize_keys.each do |key, value|
          raise ArgumentError, "Invalid key '#{key}'" unless VALID_KEYS.include?(key)
          instance_variable_set("@#{key}", value)
        end

        [:name, :active_directory_authority, :resource_manager_url].each do |key|
          unless instance_variable_get("@#{key}")
            raise ArgumentError, "Mandatory argument '#{key}' not set"
          end
        end
      end

      alias authority_url active_directory_authority
      alias resource_url resource_manager_url

      # Pre-generated environments
      Public = new(
        :name                          => 'TestStack',
        :active_directory_authority    => 'https://login.windows.net/',
        :active_directory_resource_id  => 'https://management.poc.avahc.com/01a7976d-5a10-475d-b39d-01993f9d7d90',
        :gallery_url                   => 'https://gallery.westus.stackpoc.com/',
        :graph_url                     => 'https://graph.westus.stackpoc.com/',
        :graph_api_version             => '1.6',
        :key_vault_dns_suffix          => 'vault.westus.stackpoc.com',
        :key_vault_service_resource_id => 'https://vault.westus.stackpoc.com/',
        :publish_settings_file_url     => 'https://management.westus.stackpoc.com/publishsettings/index',
        :resource_manager_url          => 'https://management.westus.stackpoc.com/',
        :service_management_url        => 'https://management.westus.stackpoc.com/',
        :sql_database_dns_suffix       => 'westus.stackpoc.com',
        :storage_suffix                => 'westus.stackpoc.com',
        :traffic_manager_dns_suffix    => 'trafficmanager.net',
      )
      #Public = new(
      #  :name                          => 'Public',
      #  :active_directory_authority    => 'https://login.microsoftonline.com/',
      #  :active_directory_resource_id  => 'https://management.core.windows.net/',
      #  :gallery_url                   => 'https://gallery.azure.com/',
      #  :graph_url                     => 'https://graph.windows.net/',
      #  :graph_api_version             => '1.6',
      #  :key_vault_dns_suffix          => 'vault.azure.net',
      #  :key_vault_service_resource_id => 'https://vault.azure.net',
      #  :publish_settings_file_url     => 'https://manage.windowsazure.com/publishsettings/index',
      #  :resource_manager_url          => 'https://management.azure.com/',
      #  :service_management_url        => 'https://management.core.windows.net/',
      #  :sql_database_dns_suffix       => 'database.windows.net',
      #  :storage_suffix                => 'core.windows.net',
      #  :traffic_manager_dns_suffix    => 'trafficmanager.net',
      #)

      USGovernment = new(
        :name                          => 'US Government',
        :active_directory_authority    => 'https://login-us.microsoftonline.com/',
        :active_directory_resource_id  => 'https://management.core.usgovcloudapi.net/',
        :gallery_url                   => 'https://gallery.usgovcloudapi.net/',
        :graph_url                     => 'https://graph.windows.net/',
        :graph_api_version             => '1.6',
        :key_vault_dns_suffix          => 'vault.usgovcloudapi.net',
        :key_vault_service_resource_id => 'https://vault.usgovcloudapi.net',
        :publish_settings_file_url     => 'https://manage.windowsazure.us/publishsettings/index',
        :resource_manager_url          => 'https://management.usgovcloudapi.net/',
        :service_management_url        => 'https://management.core.usgovcloudapi.net/',
        :sql_database_dns_suffix       => 'database.usgovcloudapi.net',
        :storage_suffix                => 'core.usgovcloudapi.net',
        :traffic_manager_dns_suffix    => 'usgovtrafficmanager.net',
      )

      Germany = new(
        :name                          => 'Germany',
        :active_directory_authority    => 'https://login.microsoftonline.de/',
        :active_directory_resource_id  => 'https://management.core.cloudapi.de/',
        :gallery_url                   => 'https://gallery.cloudapi.de/',
        :graph_url                     => 'https://graph.cloudapi.de/',
        :graph_api_version             => '1.6',
        :key_vault_dns_suffix          => 'vault.microsoftazure.de',
        :key_vault_service_resource_id => 'https://vault.microsoftazure.de',
        :publish_settings_file_url     => 'https://manage.microsoftazure.de/publishsettings/index',
        :resource_manager_url          => 'https://management.microsoftazure.de/',
        :service_management_url        => 'https://management.core.cloudapi.de/',
        :sql_database_dns_suffix       => 'database.cloudapi.de',
        :storage_suffix                => 'core.cloudapi.de',
        :traffic_manager_dns_suffix    => 'azuretrafficmanager.de'
      )

      China = new(
        :name                          => 'China',
        :active_directory_authority    => 'https://login.chinacloudapi.cn',
        :active_directory_resource_id  => 'https://management.core.chinacloudapi.cn/',
        :gallery_url                   => 'https://gallery.chinacloudapi.cn/',
        :graph_url                     => 'https://graph.chinacloudapi.cn/',
        :graph_api_version             => '1.6',
        :key_vault_dns_suffix          => 'vault.azure.cn',
        :key_vault_service_resource_id => 'https://vault.azure.cn',
        :publish_settings_file_url     => 'http://go.microsoft.com/fwlink/?LinkID=301776',
        :resource_manager_url          => 'https://management.chinacloudapi.cn/',
        :service_management_url        => 'https://management.core.chinacloudapi.cn/',
        :sql_database_dns_suffix       => 'database.chinacloudapi.cn',
        :storage_suffix                => 'core.chinacloudapi.cn',
        :traffic_manager_dns_suffix    => 'trafficmanager.cn'
      )
    end
  end
end
