require 'date'
require 'time'
require 'sphincter'

##
# Search extension for ActiveRecord::Base that automatically extends
# ActiveRecord::Base.

module Sphincter::Search

  ##
  # Struct to hold search results.
  #
  # records:: ActiveRecord objects returned by sphinx
  # total:: Total records searched
  # per_page:: Size of each chunk of records

  Results = Struct.new :records, :total, :per_page

  ##
  # Indexes registered with add_index.

  @@indexes ||= Hash.new { |h, model| h[model] = [] }

  ##
  # Accessor for indexes registered with add_index.

  def self.indexes
    @@indexes
  end

  ##
  # Adds an index with +options+.
  #
  # add_index will automatically add Sphincter::AssociationSearcher to any
  # has_many associations referenced by this model's belongs_to associations.
  # If this model belongs_to another model, and that model has_many of this
  # model, then you will be able to <tt>other.models.search</tt> and recieve
  # only records in the association.
  #
  # Currently, only has_many associations without conditions will have
  # AssociationSearcher appended.
  #
  # Options are:
  #
  # :name:: Name of index.  Defaults to ActiveRecord::Base::table_name.
  # :fields:: Array of fields to index.  Foreign key columns for belongs_to
  #           associations are automatically added.  Fields from associations
  #           may be included by using "association.field".
  # :conditions:: Array of SQL conditions that will be ANDed together to
  #               predicate inclusion in the search index.
  #
  # Example:
  #
  #   class Post < ActiveRecord::Base
  #     belongs_to :user
  #     belongs_to :blog
  #     has_many :comments
  #   
  #     add_index :fields => %w[title body user.name, comments.body],
  #               :conditions => ['published = 1']
  #   end
  #
  # When including fields from associations, MySQL's GROUP_CONCAT() function
  # is used.  By default this will create a string up to 1024 characters long.
  # A larger string can be used by changing the value of MySQL's
  # group_concat_max_len variable.  To do this, add the following to your
  # sphincter.RAILS_ENV.yml files:
  #
  #   mysql:
  #     sql_query_pre:
  #       - SET NAMES utf8
  #       - SET SESSION group_concat_max_len = VALUE

  def add_index(options = {})
    options[:fields] ||= []

    reflect_on_all_associations.each do |my_assoc|
      next unless my_assoc.macro == :belongs_to

      options[:fields] << my_assoc.primary_key_name.to_s

      has_many_klass = my_assoc.class_name.constantize

      has_many_klass.reflect_on_all_associations.each do |opp_assoc|
        next if opp_assoc.class_name != name or
                opp_assoc.macro != :has_many or
                opp_assoc.options[:conditions]

        extends = Array(opp_assoc.options[:extend])
        extends << Sphincter::AssociationSearcher
        opp_assoc.options[:extend] = extends
      end
    end

    options[:fields].uniq!

    Sphincter::Search.indexes[self] << options
  end

  ##
  # Converts +values+ into an Array of values SetFilter can digest.
  #
  # true/false becomes 1/0, Time/Date/DateTime becomes a time in epoch
  # seconds.  Everything else is passed straight through.

  def sphincter_convert_values(values)
    values.map do |value|
      case value
      when Date, DateTime then Time.parse(value.to_s).to_i
      when FalseClass then 0
      when Time then value.to_i
      when TrueClass then 1
      else value
      end
    end
  end

  ##
  # Searches for +query+ with +options+.
  #
  # Allowed options are:
  #
  # :between:: Hash of Sphinx range filter conditions.  Hash keys are sphinx
  #            group_column or date_column names.  Values can be
  #            Date/Time/DateTime or Integers.
  # :conditions:: Hash of Sphinx value filter conditions.  Hash keys are
  #               sphinx group_column or date_column names.  Values can be a
  #               single value or an Array of values.
  # :index:: Name of Sphinx index to search.  Defaults to
  #          ActiveRecord::Base::table_name.
  # :page:: Page offset of records to return, for easy use with paginators.
  # :per_page:: Size of a page.  Default page size is controlled by the
  #             configuration.
  #
  # Returns a Sphincter::Search::Results object.

  def search(query, options = {})
    sphinx = Sphinx::Client.new

    @host ||= Sphincter::Configure.get_conf['sphincter']['host']
    @port ||= Sphincter::Configure.get_conf['sphincter']['port']

    sphinx.SetServer @host, @port

    options[:conditions] ||= {}
    options[:conditions].each do |column, values|
      values = sphincter_convert_values Array(values)
      sphinx.SetFilter column.to_s, values
    end

    options[:between] ||= {}
    options[:between].each do |column, between|
      min, max = sphincter_convert_values between

      sphinx.SetFilterRange column.to_s, min, max
    end

    @default_per_page ||= Sphincter::Configure.get_conf['sphincter']['per_page']

    per_page = options[:per_page] || @default_per_page
    page_offset = options.key?(:page) ? options[:page] - 1 : 0
    offset = page_offset * per_page

    sphinx.SetLimits offset, per_page

    index_name = options[:index] || table_name

    sphinx_result = sphinx.Query query, index_name

    matches = sphinx_result['matches'].sort_by do |id, match|
      -match['index'] # #find reverses, lame!
    end

    ids = matches.map do |id, match|
      (id - match['attrs']['sphincter_index_id']) /
        Sphincter::Configure.index_count
    end

    results = Results.new

    results.records = find ids
    results.total = sphinx_result['total_found']
    results.per_page = per_page

    results
  end

end

# :stopdoc:
module ActiveRecord; end
class ActiveRecord::Base; end
ActiveRecord::Base.extend Sphincter::Search
# :startdoc:

