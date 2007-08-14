require 'rake'
require 'sphincter/configure'

namespace :sphincter do

  desc 'Creates sphinx.conf if it doesn\'t exist'
  task :configure => :environment do
    sphinx_conf = Sphincter::Configure.sphinx_conf
    Rake::Task['sphincter:reconfigure'].invoke unless File.exist? sphinx_conf
  end

  desc 'Creates sphinx.conf'
  task :reconfigure => :environment do
    Sphincter::Configure.configure
  end

  desc 'Runs the sphinx indexer if the indexes don\'t exist'
  task :index => :configure do
    indexes_defined = Sphincter::Configure.index_count
    sphinx_dir = Sphincter::Configure.get_conf['sphincter']['path']

    indexes_found = Dir[File.join(sphinx_dir, '*.spd')].length

    Rake::Task['sphincter:reindex'].invoke if indexes_found > indexes_defined
  end

  desc 'Runs the sphinx indexer'
  task :reindex => :configure do
    sphinx_conf = Sphincter::Configure.sphinx_conf
    cmd = %W[indexer --all --config #{sphinx_conf}]
    cmd << "--quiet" unless Rake.application.options.trace
    cmd << "--rotate" if Sphincter::Configure.searchd_running?
    system(*cmd)
  end

  desc 'Stops searchd, reconfigures and reindexes'
  task :reset => :configure do
    Rake::Task['sphincter:stop_searchd'].invoke
    FileUtils.rm_rf Sphincter::Configure.sphinx_dir,
                    :verbose => Rake.application.options.trace
    Rake::Task['sphincter:reconfigure'].execute # force reindex
    Rake::Task['sphincter:reindex'].invoke
  end

  desc 'Restarts the searchd sphinx daemon'
  task :restart_searchd => %w[sphincter:stop_searchd sphincter:start_searchd]

  desc 'Sets up the sphinx client'
  task :setup_sphinx do
    require 'fileutils'
    require 'tmpdir'
    require 'open-uri'

    verbose = Rake.application.options.trace

    begin
      tmpdir = File.join Dir.tmpdir, "Sphincter_setup_#{$$}"

      mkdir tmpdir, :verbose => true

      chdir tmpdir

      src = open "http://rubyforge.org/frs/download.php/19571/sphinx-0.3.0.zip"
      File.open('sphinx-0.3.0.zip', 'wb') { |dst| dst.write src.read }

      quiet = verbose ? '' : ' -q'
      sh "unzip#{quiet} sphinx-0.3.0.zip" or
        raise "couldn't unzip sphinx-0.3.0.zip"

      File.open 'sphinx.patch', 'wb' do |patch|
        patch.puts <<-EOF
--- sphinx/lib/client.rb.orig	2007-04-05 06:38:14.000000000 -0700
+++ sphinx/lib/client.rb	2007-07-29 20:23:18.000000000 -0700
@@ -398,6 +398,7 @@
   \r
         result['matches'][doc] ||= {}\r
         result['matches'][doc]['weight'] = weight\r
+        result['matches'][doc]['index'] = count\r
         attrs_names_in_order.each do |attr|\r
           val = response[p, 4].unpack('N*').first; p += 4\r
           result['matches'][doc]['attrs'] ||= {}\r
        EOF
      end

      quiet = verbose ? ' --verbose' : ''
      sh "patch#{quiet} -p0 sphinx/lib/client.rb sphinx.patch" or
        raise "couldn't patch sphinx"

      sphinx_plugin_dir = File.join RAILS_ROOT, 'vendor', 'plugins', 'sphinx'
      rm_rf sphinx_plugin_dir, :verbose => true

      mv 'sphinx', sphinx_plugin_dir, :verbose => true
    ensure
      rm_rf tmpdir, :verbose => true
    end
  end

  desc 'Starts the searchd sphinx daemon'
  task :start_searchd => :index do
    unless Sphincter::Configure.searchd_running? then
      cmd = "searchd --config #{Sphincter::Configure.sphinx_conf}"
      cmd << " > /dev/null" unless Rake.application.options.trace
      system cmd
    end
  end

  desc 'Stops the searchd daemon'
  task :stop_searchd => :configure do
    pid = Sphincter::Configure.searchd_running?
    system 'kill', pid if pid
  end

end

