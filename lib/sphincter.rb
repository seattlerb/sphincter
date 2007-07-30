$TESTING = defined?($TESTING) && $TESTING

##
# Sphincter is a ActiveRecord extension for full-text searching using the
# Sphinx library.
#
# For the quick-start guide and some examples, see README.txt.
#
# == Installing
#
# Download and install Sphinx from http://www.sphinxsearch.com/downloads.html
#
# Download Sphinx Ruby API from
# http://rubyforge.org/frs/?group_id=2604&release_id=11049
#
# Unpack Sphinx Ruby API into vendor/plugins/.
#
# Install the gem:
#
#   gem install Sphincter
#
# Require Sphincter in config/environment.rb:
#
#   require 'sphincter'
#
# Require the Sphincter rake tasks in Rakefile:
#
#   require 'sphincter/tasks'
#
# == Setup
#
# At best, you don't do anything to setup Sphincter.  It has sensible built-in
# defaults.
#
# If you're running Sphinx's searchd for multiple environments on the same
# machine, you'll want to add a config file to change the port that searchd
# and the RAILS_ENV will comminicate across.  Do that in a per-environment
# configuration file.
#
# If you have multiple machines, you'll want to change which address searchd
# will run on.  Do that in the global configuration file.
#
# See Sphincter::Configure for full information on how to setup these and
# other options for Sphincter.
#
# When you're done, run:
#
#  $ rake sphincter:configure
#
# == Indexing
#
# Sphincter automatically extends ActiveRecord::Base with Sphincter::Search, so
# you only have to call add_index in the models you want indexed:
#
#   class Model < ActiveRecord::Base
#     belongs_to :other
#   
#     add_index :fields => %w[title body]
#   end
#   
#   class Other < ActiveRecord::Base
#     has_many :models
#   end
#
# add_index automatically adds a #search method to has_many associations
# referencing this model, so you could:
#
#   Other.find(id).models.search 'some query'
#
# See Sphincter::Search for details.
#
# When you're done, run:
#
#   rake sphincter:index
#
# == Tasks
#
# You can get a set of Sphincter tasks by requiring 'sphincter/tasks' in your
# Rakefile.  These tasks are all in the 'sphincter' namespace:
#
# configure:: Creates sphinx.conf if it doesn't exist
# reconfigure:: Creates sphinx.conf, replacing the existing one.
# index:: Runs the sphinx indexer if the index doesn't exist.
# reindex:: Runs the sphinx indexer.  Rotates the index if searchd is running.
# reset:: Stops searchd, reconfigures and reindexes
# restart_searchd:: Restarts the searchd sphinx daemon
# start_searchd:: Starts the searchd sphinx daemon
# stop_searchd:: Stops the searchd daemon

module Sphincter

  ##
  # This is the version of Sphincter you are using.

  VERSION = '1.0.0'

end

require 'sphincter/configure'
require 'sphincter/association_searcher'
require 'sphincter/search'

