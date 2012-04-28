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
              options = property_to_mapping(property)

              property.options.each do |k,v|
                unless [:type, :default, :index_type, :nested_type].include?(k)
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

        def map_child_type(property)
          {:type => (property.options[:index_type] || :nested), :properties => property.type.to_mapping_properties }
        end
        
        def map_array(property)
          if property.options[:index_type]
            mapping = type_to_mapping(property.options[:index_type])
          else
            mapping = {:type => :nested}
          end
          
          if property.options[:nested_type]
            mapping[:properties] = property.options[:nested_type].to_mapping_properties
          end
          
          mapping
        end
        
        def property_to_mapping(property)
          if property.type == Array
            map_array(property)                          
          elsif property.type.ancestors.include?(::CouchPotato::Persistence)
            map_child_type(property)
          else
            type_to_mapping(property.type)
          end
        end
        
        def type_to_mapping(type)
          if type == String
            {:type => :string}
          elsif type == Time
            {:type => :date}
          end
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