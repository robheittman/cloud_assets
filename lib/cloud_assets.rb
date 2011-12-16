require "cloud_assets/version"

module CloudAssets

  ApplicationController.class_eval do

    def handle_response(response)
      if response.is_a? Hash
        response
      else
        if response.success?
          JSON.parse(response.body)
        elsif response.code == 404
          nil
        else
          raise response.body
        end
      end
    end

    def cloud_asset(path)
      p = "#{ENV['CLOUD_ASSET_ORIGIN']}#{path}"
      puts "Fetching from #{p}"
      hydra = Typhoeus::Hydra.new
      hydra.cache_getter do |request|
        $dalli_cache.get(request.cache_key) rescue nil
      end
      hydra.cache_setter do |request|
        $dalli_cache.set(request.cache_key, request.response, request.cache_timeout)
      end
      request = Typhoeus::Request.new p, {:follow_location => true, :max_redirects => 3, :cache_timeout => 300000}
      asset_response = nil
      request.on_complete do |hydra_response|
        asset_response = hydra_response
      end
      hydra.queue request
      hydra.run
      asset_response
    end

    def optimize_uri(src)
      if src.nil?
        return nil
      end
      puts "optimizing #{src}"
      if ENV['CLOUD_ASSET_CDN'].nil?
        o = ENV['CLOUD_ASSET_ORIGIN']
      else
        o = ENV['CLOUD_ASSET_CDN']
      end
      src = src.gsub(ENV['CLOUD_ASSET_ORIGIN'],'')
      src = "#{o}#{src}"
      puts "optimized #{src}"
      src
    end

    def correct_uri(src)
     src = src.gsub(ENV['CLOUD_ASSET_ORIGIN'],'')
    end

    def optimized_html_for(asset_response)
      doc = Nokogiri::HTML(asset_response.body)

      { 'img' => 'src',
        'link' => 'href' }.each do |tag,attribute|
        doc.css(tag).each do |e|
          unless e[attribute].nil?
            e[attribute] = optimize_uri(e[attribute])
          end
        end
      end

      { 'a' => 'href',
        'script' => 'src' }.each do |tag,attribute|
        doc.css(tag).each do |e|
          unless e[attribute].nil?
            e[attribute] = correct_uri(e[attribute])
          end
        end
      end

      doc
    end

    helper_method :inject_into_cms_layout
    def inject_into_cms_layout(hash)
      if @injections.nil?
        @injections = {}
      end
      @injections.merge! hash
    end

    helper_method :override_cms_layout
    def override_cms_layout(hash)
      if @overrides.nil?
        @overrides = {}
      end
      @overrides.merge! hash
    end

    helper_method :set_cms_layout_template
    def set_cms_layout_template(template)
      @template = template
    end

    helper_method :apply_cms_layout
    def apply_cms_layout
      if @template.nil?
        @template = "/templates/page.html"
      end
      if @template.kind_of? String
        puts "Fetching fresh template #{@template}"
        doc = optimized_html_for cloud_asset "#{@template}"
      else
        puts "Using already fetched template"
        doc = optimized_html_for @template
      end
      unless @overrides.nil?
        @overrides.each do |key, value|
          begin
            doc.at_css(key).inner_html = value
            puts "Overrode template element: #{key}"
          rescue
            puts "Failed to override template element: #{key}"
          end
        end
      end
      unless @injections.nil?
        @injections.each do |key, value|
          begin
            doc.at_css(key).add_child(value)
            puts "Injected data into template element: #{key}"
          rescue
            puts "Failed to inject data into template element: #{key}"
          end
        end
      end
      doc
    end

  end

end
