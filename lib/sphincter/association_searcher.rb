require 'sphincter'

##
# ActiveRecord::Associations::ClassMethods#has_many extension for searching
# the items of an ActiveRecord::Associations::AssociationProxy.

module Sphincter::AssociationSearcher

  ##
  # Searches for +query+ with +options+.  Adds a condition so only the
  # proxy_owner's records are matched.

  def search(query, options = {})
    pkey = proxy_reflection.primary_key_name
    options[:conditions] ||= {}
    options[:conditions][pkey] = proxy_owner.id

    proxy_reflection.klass.search query, options
  end

end

