Sphincter

Eric Hodel <drbrain@segment7.net>

http://seattlerb.org/Sphincter

Sphincter was named by David Yeu.

== DESCRIPTION:

Sphincter is an ActiveRecord extension for full-text searching with Sphinx.

Sphincter uses Dmytro Shteflyuk's sphinx Ruby API and automatic
configuration to make totally rad ActiveRecord searching.  Well, you
still have to tell Sphincter what models you want to search.  It
doesn't read your mind.

For complete documentation:

  ri Sphincter

== FEATURES:

* Automatically configures itself.
* Handy set of rake tasks for easy, automatic management.
* Automatically adds has_many metadata for searching across the
  association.
* Stub for testing without connecting to searchd, Sphincter::SearchStub.
* Easy pagination support.
* Filtering by index metadata and ranges, including dates.

== PROBLEMS:

* Setting match mode not supported.
* Setting sort mode not supported.
* Setting per-field weights not supported.
* Setting id range not supported.
* Setting group-by not supported.

== QUICK-START:

Download and install Sphinx from http://www.sphinxsearch.com/downloads.html

Download Sphinx Ruby API from http://rubyforge.org/frs/?group_id=2604&release_id=11049

Unpack Sphinx Ruby API into vendor/plugins/.

Install Sphincter:

  $ gem install Sphincter

Load Sphincter in config/environment.rb:

  require 'sphincter'

By default, Sphincter will run searchd on the same port for all
environments.  See Sphincter::Configure for how to configure different
environments to use different ports.

Add indexes to models:

  class Post < ActiveRecord::Base
    belongs_to :blog
    add_index :fields => %w[title body published]
  end

Add searching UI:

  class BlogController < ApplicationController
    def search
      @blog = Blog.find params[:id]

      @results = @blog.posts.search params[:q]
    end
  end

Start searchd:

  $ rake sphincter:start_searchd

Then test it out in your browser.

== TESTING QUICK-START:

See Sphinx::SearchStub.

== EXAMPLES:

See Sphincter::Search#search for full documentation.

Example ActiveRecord model:

  class Post < ActiveRecord::Base
    belongs_to :blog
  
    # published is a boolean and title and body are string or text fields
    add_index :fields => %w[title body published]
  end
  
Simple search:

  Post.search 'words'
  
Only search published posts:

  Post.search 'words', :conditions => { :published => 1 }
  
Only search posts created in the last week:

  now = Time.now
  ago = now - 1.weeks
  Post.search 'words', :between => { :created_on => [ago, now] }
  
Pagination (defaults to ten records/page):

  Post.search 'words', :page => 2
  
Pagination with custom page size:

  Post.search 'words', :page => 2, :per_page => 20
  
Pagination with custom page size (better):

Add to config/sphincter.yml:

  sphincter:
    per_page: 20

Then search:

  Post.search 'words', :page => 2

