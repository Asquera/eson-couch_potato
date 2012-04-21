require 'eson'
require 'eson/couch_potato/database'
require 'eson/couch_potato/search_result'
require 'eson/couch_potato/search_results'
require 'eson/couch_potato/searchable'

# revert symbol monkeypatch
class Symbol
  def as_json(*)
    to_s
  end
end

class CouchPotato::Database
  include Eson::CouchPotato::Database
end
