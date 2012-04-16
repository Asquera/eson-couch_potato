require 'bundler/setup'

Bundler.require(:default, :test)

require 'eson-couch_potato'
require 'elasticsearch-node/external'

module Node
  module External
    def self.instance
      @node ||= begin
        node = ElasticSearch::Node::External.new("gateway.type" => "none")
        at_exit do
          node.close
        end
        node
      end
    end
  end
end

CouchPotato::Config.database_name = 'eson-test'

Node::External.instance
require 'riot'
