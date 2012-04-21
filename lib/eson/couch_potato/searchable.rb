module Eson
  module CouchPotato
    module Searchable
      include SearchResult

      def self.included(base)
        base.extend(ClassMethods)
      end

      def index(opts = {})
        database.index_document self, opts
      end

      def more_like_this(opts = {})
        database.more_like_this self, opts
      end
      alias :mlt :more_like_this

      module ClassMethods
        def search(name, opts = {}, &block)
          meta = class << self; self; end

          meta.class_eval do
            define_method(name) do |*args|
              opts[:type] = self.name
              opts.merge(Eson::Search::BaseQuery.new(*args, &block).to_query_hash)
            end
          end
        end
      end
    end
  end
end