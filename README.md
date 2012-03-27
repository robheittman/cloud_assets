cloud_assets enables a Rails app to make transparent use of
assets on a remote server in an alternative technology.

Principles and modes of operation
---------------------------------

You can avoid incorporating static assets in your Rails
app directly, if they exist somewhere else on the internet.
With cloud_assets you configure your Rails app as the
front end for assets managed in another internet-connected
system, e.g. WordPress, Drupal, SharePoint, etc.

Instead of returning a 404 Not Found, cloud_assets will
proxy a pooled request to the remote server, cache the
content locally, and serve it from Rails.

cloud_assets also provides tools and vocabulary for making
Rails views that make use of HTML originating on the
remote system, and rewrites URIs in such templates to
point either to the local Rails system or a CDN, depending
on configuration and utility.

Installation
------------

1.

  Add cloud_assets to your Gemfile and bundle install, then
  define the following in your environment.

  Required:
  CLOUD_ASSET_ORIGIN - Origin URI for remote assets

  Optional:
  CLOUD_ASSET_CDN - Content delivery network, if any. This
  is used to rewrite URIs for images and other large static
  assets to the CDN instead of Rails.

  CLOUD_ASSET_USER, CLOUD_ASSET_PASSWORD - HTTP Basic
  credentials which will be used when retrieving assets from
  the cloud asset source.

2.

  Put a route at the bottom of your routes.rb:

  match '*url' => 'cloud_assets#content'

  This will allow cloud_assets to handle anything Rails
  doesn't recognize.

3.

  In application_controller.rb:

  include CloudAssets

Additional Configuration
------------------------

If you are serving any non-trivial amount of remotely
sourced assets out of your Rails system, you'll want a cache.
cloud_assets likes memcached via dalli.

To enable it, just define $dalli_cache somewhere in one of
your initializers.

Usage
-----

Set a remote layout for an HTML view by defining the URI to
the layout on the remote system, e.g.

  set_remote_layout '/templates/foo.html'

You can inject additional content into the elements of that
template, or override the interior of its elements, using CSS
selectors:

  inject_into_remote_layout '#notice' => flash[:notice]
  override_remote_layout 'body' => yield

Finally, obtain and show the result (complete with rewrites
of CDN URLs and so on) with:

  apply_remote_layout
