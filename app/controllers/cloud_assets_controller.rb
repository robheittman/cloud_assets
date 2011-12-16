class CloudAssetsController < ApplicationController
  def content
    asset_response = cloud_asset request.fullpath
    if asset_response.success?
      content_type = asset_response.headers_hash['Content-type']
      if content_type.kind_of? Array
        content_type = content_type.pop
      end
      if content_type =~ /text\/html/
        set_cms_layout_template asset_response
        response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate, max-age=0'
        render :html => ''
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
