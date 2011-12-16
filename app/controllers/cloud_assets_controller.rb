require 'typhoeus'

class CloudAssetsController < ApplicationController

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

  helper_method :inject_into_remote_layout
  def inject_into_remote_layout(hash)
    if @injections.nil?
      @injections = {}
    end
    @injections.merge! hash
  end

  helper_method :override_remote_layout
  def override_remote_layout(hash)
    if @overrides.nil?
      @overrides = {}
    end
    @overrides.merge! hash
  end

  helper_method :set_remote_layout
  def set_remote_layout(layout)
    @remote_layout = layout
  end

  helper_method :apply_remote_layout
  def apply_remote_layout
    if @remote_layout.nil?
      @remote_layout = "/templates/page.html"
    end
    if @remote_layout.kind_of? String
      puts "Fetching fresh template #{@remote_layout}"
      doc = optimized_html_for cloud_asset "#{@remote_layout}"
    else
      puts "Using already fetched template"
      doc = optimized_html_for @remote_layout
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

  def content
    asset_response = cloud_asset request.fullpath
    if asset_response.success?
      content_type = asset_response.headers_hash['Content-type']
      if content_type.kind_of? Array
        content_type = content_type.pop
      end
      if content_type =~ /text\/html/
        set_remote_layout asset_response
        response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate, max-age=0'
        render :html => '', :template => nil
      else
        puts "Warning: inefficient pass-through of #{content_type} at #{request.fullpath}"
        response.headers['Cache-Control'] = 'max-age=60'
        send_data asset_response.body, :type => content_type, :disposition => 'inline'
      end
    else
      render :status => :not_found
    end
  end

end
