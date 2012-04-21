module Eson
  module CouchPotato
    module SearchResults
      attr_accessor :results

      def total
        results["hits"]["total"]
      end

      def max_score
        results["hits"]["max_score"]
      end
    end
  end
end