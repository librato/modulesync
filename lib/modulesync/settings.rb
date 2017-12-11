
module ModuleSync
  # Encapsulate a configs for a module, providing easy access to its parts
  # All configs MUST be keyed by the relative target filename
  class Settings
    attr_reader :global_defaults, :defaults, :module_defaults, :module_configs, :additional_settings

    def initialize(global_defaults, defaults, module_defaults, module_configs, additional_settings)
      @global_defaults = global_defaults
      @defaults = defaults
      @module_defaults = module_defaults
      @module_configs = module_configs
      @additional_settings = additional_settings
    end

    def lookup_config(hash, target_name)
      hash[target_name] || {}
    end

    def build_file_configs(target_name)
      file_def = lookup_config(defaults, target_name)
      file_md  = lookup_config(module_defaults, target_name)
      file_mc  = lookup_config(module_configs, target_name)

      global_defaults.smart_merge(file_def).smart_merge(file_md).smart_merge(file_mc).smart_merge(additional_settings)
    end

    def managed?(target_name)
      Pathname.new(target_name).ascend do |v|
        configs = build_file_configs(v.to_s)
        return false if configs['unmanaged']
      end
      true
    end

    # given a list of templates in the repo, return everything that we might want to act on
    def managed_files(target_name_list)
      (target_name_list | defaults.keys | module_configs.keys).select do |f|
        (f != ModuleSync::GLOBAL_DEFAULTS_KEY) && managed?(f)
      end
    end

    # returns a list of templates that should not be touched
    def unmanaged_files(target_name_list)
      (target_name_list | defaults.keys | module_configs.keys).select do |f|
        (f != ModuleSync::GLOBAL_DEFAULTS_KEY) && !managed?(f)
      end
    end
  end
end

class Hash
    # Merge two hashes according to the following rules for duplicate keys:
    # 1. If the values don't match, take the new hash's value
    # 2. If the values are hashes merge recursively
    # 3. If the values are arrays, take their union minus duplicates
    # 4. If the values are scalars, take the new hash's value
    # The idea is that generally, with matching hash keys we want to replace scalar values and
    # combine array values e.g. add the module's config list to a global list
    # TODO: add fancier logic e.g. set an "override" flag which sticks
    # to Hash.merge's default behavior, see https://apidock.com/ruby/Hash/merge
    # Also, note that this method does not recursively process hashes when they are
    # array elements
    def smart_merge(new_hash)
      self.merge(new_hash) do |key, old, new|
        if old.class != new.class
          new
        elsif (old.is_a? Hash)
          old.smart_merge(new)
        elsif (old.is_a? Array)
          (old + new).uniq
        elsif (old.is_a? String) || (old.is_a? Numeric)
          new
        end
      end
    end
end
