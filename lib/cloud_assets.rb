require "cloud_assets/version"

module CloudAssets

  class Engine < Rails::Engine

     module ControllerMethods

        require 'typhoeus'
        require 'nokogiri'

        def cloud_asset(path)
          p = "#{ENV['CLOUD_ASSET_ORIGIN']}#{path}"
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
            :cache_timeout => 604800
          }
          unless ENV['CLOUD_ASSET_USER'].nil?
            options[:username] = ENV['CLOUD_ASSET_USER']
            options[:password] = ENV['CLOUD_ASSET_PASSWORD']
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
          o = ENV['CLOUD_ASSET_CDN'] || ''
          src.gsub!(ENV['CLOUD_ASSET_ORIGIN'],'')
          return src if src =~ /^http:/
          "#{o}#{src}"
        end

        def correct_uri(src)
          src.gsub(ENV['CLOUD_ASSET_ORIGIN'],'')
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
            doc
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
