require "cloud_assets/version"

module CloudAssets

  def self.setup
    yield self
  end

  mattr_accessor :origin
  @@origin = ENV['CLOUD_ASSET_ORIGIN']

  mattr_accessor :user
  @@user = ENV['CLOUD_ASSET_USER']

  mattr_accessor :password
  @@password = ENV['CLOUD_ASSET_PASSWORD']

  mattr_accessor :cdn
  @@cdn = ENV['CLOUD_ASSET_CDN'] || ''

  # How long objects from the source can be kept in our local cache
  mattr_accessor :cache_timeout_seconds
  @@cache_timeout_seconds = 604800

  # How long to allow clients (and CDN) to keep javascript assets
  mattr_accessor :javascript_max_age_seconds
  @@javascript_max_age_seconds = 600

  # How long to allow clients (and CDN) to keep css assets
  mattr_accessor :css_max_age_seconds
  @@css_max_age_seconds = 600

  # How long to allow clients (and CDN) to keep other assets
  mattr_accessor :other_max_age_seconds
  @@other_max_age_seconds = 86400

  mattr_accessor :verbose
  @@verbose = false

  class Engine < Rails::Engine

     module ControllerMethods

        require 'typhoeus'
        require 'nokogiri'

        def cloud_asset(path)
          p = "#{CloudAssets::origin}#{path}"
          hydra = Typhoeus::Hydra.new
          unless $dalli_cache.nil?
            hydra.cache_getter do |request|
              $dalli_cache.get(request.cache_key) rescue nil
            end
            hydra.cache_setter do |request|
              $dalli_cache.set(request.cache_key, request.response, request.cache_timeout)
            end
          end
          options = {
            :follow_location => true,
            :max_redirects => 3,
            :cache_timeout => CloudAssets::cache_timeout_seconds
          }
          unless CloudAssets::user.nil?
            options[:username] = CloudAssets::user
            options[:password] = CloudAssets::password
            options[:auth_method] = :basic
          end
          if CloudAssets.verbose
            puts "Retrieving remote asset #{p}"
          end
          request = Typhoeus::Request.new p, options
          asset_response = nil
          request.on_complete do |hydra_response|
            asset_response = hydra_response
          end
          hydra.queue request
          hydra.run
          asset_response
        end

        def optimize_uri(src)
          return nil if src.nil?
          o = CloudAssets::cdn || ''
          src.gsub!(CloudAssets::origin,'')
          return src if src =~ /^http:/
          "#{o}#{src}"
        end

        def correct_uri(src)
          src.gsub(CloudAssets::origin,'')
        end

        def optimized_html_for(asset_response)
          doc = Nokogiri::HTML(asset_response.body)

          { 'img' => 'src',
            'link' => 'href' }.each do |tag,attribute|
            doc.css(tag).each do |e|
              if tag == 'link' and e['rel'] != 'stylesheet'
                next
              end
              unless e[attribute].nil?
                e[attribute] = optimize_uri(e[attribute])
              end
            end
          end

          { 'a' => 'href',
            'script' => 'src',
            'link' => 'href' }.each do |tag,attribute|
            doc.css(tag).each do |e|
              if tag == 'link' and e['rel'] == 'stylesheet'
                next
              end
              unless e[attribute].nil?
                e[attribute] = correct_uri(e[attribute])
              end
            end
          end

          doc
        end

        def inject_into_remote_layout(hash)
          if @injections.nil?
            @injections = {}
          end
          @injections.merge! hash
        end

        def override_remote_layout(hash)
          if @overrides.nil?
            @overrides = {}
          end
          @overrides.merge! hash
        end

        def set_remote_layout(layout)
          @remote_layout = layout
        end

        def set_default_remote_layout(layout)
          if @remote_layout.nil?
            @remote_layout = layout
          end
        end

        def apply_remote_layout
          begin
            if @remote_layout.nil?
              raise <<-ERR
                No remote layout is defined. Use set_remote_layout or
                set_default_remote_layout in your views prior to calling
                apply_remote_layout.
              ERR
            end
            if @remote_layout.kind_of? String
              doc = optimized_html_for cloud_asset "#{@remote_layout}"
            else
              doc = optimized_html_for @remote_layout
            end
            unless @overrides.nil?
              @overrides.each do |key, value|
                begin
                  doc.at_css(key).inner_html = value
                rescue
                  puts "Failed to override template element: #{key}"
                end
              end
            end
            unless @injections.nil?
              @injections.each do |key, value|
                begin
                  doc.at_css(key).add_child(value)
                rescue
                  puts "Failed to inject data into template element: #{key}"
                end
              end
            end
            # We don't know what in-doc references might be to, so we have to make
            # them local and can't optimize them to the CDN -- at least not without
            # some serious guessing which we are not ready to do
            doc.to_s.gsub CloudAssets::origin, ''
          rescue => e
            puts e.inspect
            puts e.backtrace
            raise e
          end
        end

      end

    initializer 'cloud_assets.app_controller' do |app|
      ActiveSupport.on_load(:action_controller) do
        include ControllerMethods
        helper_method :inject_into_remote_layout
        helper_method :override_remote_layout
        helper_method :set_remote_layout
        helper_method :set_default_remote_layout
        helper_method :apply_remote_layout
      end
    end
  end

end
