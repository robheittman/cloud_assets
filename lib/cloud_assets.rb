require "cloud_assets/version"

module CloudAssets

  def self.setup
    yield self
  end

  # Monkey-patch this method if you need to hack some fixups into
  # html from your asset source.
  def self.fixup_html(html)
    html
  end

  # Monkey-patch this method if you need to hack some fixups into
  # asset requests urls
  def self.fixup_url(fullpath)
    fullpath
  end

  # Monkey-patch this method if you need to hack some fixups into
  # javascript from your asset source.
  def self.fixup_javascript(javascript)
    javascript
  end

  # Monkey-patch this method if you need to hack some fixups into
  # css from your asset source.
  def self.fixup_css(css)
    css
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
          p = CloudAssets::fixup_url("#{CloudAssets::origin}#{path}")
          hydra = Typhoeus::Hydra.hydra
          unless $dalli_cache.nil?
            hydra.cache_getter do |request|
              $dalli_cache.get(request.cache_key) rescue nil
            end
            hydra.cache_setter do |request|
              begin
                $dalli_cache.set(request.cache_key, request.response, request.cache_timeout)
              rescue
                Rails.logger.info "Attempt to save to memcached thru Dalli failed."
              end
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
            Rails.logger.debug "Retrieving remote asset #{p}"
          end
          request = Typhoeus::Request.new p, options
          asset_response = nil
          request.on_complete do |hydra_response|
            asset_response = hydra_response
          end
          hydra.queue request
          hydra.run
          if asset_response.code == 404
            raise ActionController::RoutingError.new("Remote asset not found: #{path}")
          elsif asset_response.code > 399
            raise Exception.new("Error #{asset_response.code} on remote asset server fetching #{path}")
          end
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
          doc = Nokogiri::HTML(asset_response.body,nil,'UTF-8')

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

        def replace_remote_layout(hash)
          if @replacements.nil?
            @replacements = {}
          end
          @replacements.merge! hash
        end

        def remove_remote_layout(selector)
          replace_remote_layout(selector => '')
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
              raise Exception.new(
                <<-ERR
                  No remote layout is defined. Use set_remote_layout or
                  set_default_remote_layout in your views prior to calling
                  apply_remote_layout.
                ERR
              )
            end
            if @remote_layout.kind_of? String
              doc = optimized_html_for cloud_asset "#{@remote_layout}"
            else
              doc = optimized_html_for @remote_layout
            end
            unless @replacements.nil?
              @replacements.each do |key, value|
                value = value.encode("UTF-8")
                begin
                  doc.css(key).each do |node|
                    node.replace(value)
                  end
                rescue
                  Rails.logger.warn "Failed to replace template element: #{key}"
                end
              end
            end
            unless @overrides.nil?
              @overrides.each do |key, value|
                except = {}
                if value.kind_of? Hash
                  # interpret as an option set
                  except = value[:except]
                  value = value[:value]
                end
                value = value.encode("UTF-8")
                begin
                  doc.css(key).each do |node|
                    except.each do |e|
                       node.css(e).each do |sn|
                         value << sn.to_s
                       end
                    end
                    node.inner_html = value
                  end
                rescue StandardError => e
                  Rails.logger.warn "Failed to override template element: #{key}"
                  Rails.logger.warn e
                end
              end
            end
            unless @injections.nil?
              @injections.each do |key, value|
                value = value.encode("UTF-8")
                begin
                  doc.css(key).each do |node|
                    node.add_child(value)
                  end
                rescue
                  Rails.logger.warn "Failed to inject data into template element: #{key}"
                end
              end
            end
            s = doc.serialize(:encoding => 'UTF-8')
            # We don't know what in-doc references might be to, so we have to make
            # them local and can't optimize them to the CDN -- at least not without
            # some serious guessing which we are not ready to do
            CloudAssets::fixup_html(s.gsub CloudAssets::origin, '')
          rescue => e
            Rails.logger.error e
            raise e
          end
        end

      end

    initializer 'cloud_assets.app_controller' do |app|
      ActiveSupport.on_load(:action_controller) do
        include ControllerMethods
        helper_method :inject_into_remote_layout
        helper_method :override_remote_layout
        helper_method :replace_remote_layout
        helper_method :remove_remote_layout
        helper_method :set_remote_layout
        helper_method :set_default_remote_layout
        helper_method :apply_remote_layout
        helper_method :cloud_asset
      end
    end
  end

end
