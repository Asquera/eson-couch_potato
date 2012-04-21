module Eson
  module CouchPotato
    module Database
      module Mapping
        def register_template(name, match = "*", models = CouchPotato.models, settings = nil)
          elasticsearch_client.put_template :template => match,
                                            :mappings => Array(models).inject({}) { |mappings, m| mappings.merge(m.to_mapping) },
                                            :settings => settings,
                                            :name     => name
        end
      end
    end

    module Persistence
      module Mapping
        def to_mapping_properties
          self.properties.list.inject({}) do |mapping, property|
            
            mapping[property.name] = begin
              options = if property.type == String
                          {:type => :string}
                        elsif property.type == Array
                          {:type => :string}
                        elsif property.type == Time
                          {:type => :date}
                        elsif property.type.ancestors.include?(::CouchPotato::Persistence)
                          map_child_type(property.type)
                        end

              property.options.each do |k,v|
                unless [:type, :default].include?(k)
                  options[k] = v
                end
              end

              options
            end
 
            mapping[JSON.create_id] = {:type => :string}

            mapping
          end
        end

        def to_mapping
          { name => {:properties => to_mapping_properties }}
        end

        def map_child_type(type)
          {:type => :nested, :properties => type.to_mapping_properties }
        end
      end
    end
  end
end

CouchPotato::Database.class_eval{ include Eson::CouchPotato::Database::Mapping }
Eson::CouchPotato::Searchable::ClassMethods.class_eval{ include Eson::CouchPotato::Persistence::Mapping }

class CouchPotato::Persistence::SimpleProperty
  attr_reader :options
  
  alias :old_initialize :initialize
  
  def initialize(owner_clazz, name, options = {})
    @options = options
    old_initialize(owner_clazz, name, options)
  end
end