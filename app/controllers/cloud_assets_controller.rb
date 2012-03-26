class CloudAssetsController < ApplicationController

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
        render :html => ''
      elsif content_type =~ /javascript/
        response.headers['Cache-Control'] = 'max-age=60'
        # In externally sourced JS, mask the cloud source to point here
        body = asset_response.body.gsub! CloudAssets::origin,''
        send_data body, :type => content_type, :disposition => 'inline'
      elsif content_type =~ /css/
        response.headers['Cache-Control'] = 'max-age=60'
        # In externally sourced CSS, mask the cloud source to point to the CDN
        body = asset_response.body.gsub! CloudAssets::origin, CloudAssets::cdn
        send_data body, :type => content_type, :disposition => 'inline'
      else
        response.headers['Cache-Control'] = 'max-age=3600'
        send_data asset_response.body, :type => content_type, :disposition => 'inline'
      end
    else
      render :status => :not_found
    end
  end

end
