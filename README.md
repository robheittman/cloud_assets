## cloud_assets

cloud_assets enables a Rails app to make transparent use of
assets on a remote server in an alternative technology.

## Principles and modes of operation

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

## Installation

Add cloud_assets to your Gemfile and bundle install, then
define the necessary configuration in an initializer,
e.g. config/initializers/cloud_assets.rb.

If you don't define the initializer, all the important
values will be read from the environment, which is extra
handy if you are running on Heroku.

This initializer will behave the same as no initializer;
customize to your taste.

```ruby
CloudAssets.setup do |config|

  # Required: origin URI for remote assets, e.g. http://yourhost.com
  config.origin = ENV['CLOUD_ASSET_ORIGIN']

  # If needed: HTTP Basic user for remote assets
  config.user = ENV['CLOUD_ASSET_USER']

  # If needed: HTTP Basic user for remote password
  config.password = ENV['CLOUD_ASSET_PASSWORD']

  # Rewrite URIs to use a CDN
  config.cdn = ENV['CLOUD_ASSET_CDN']

  # Activate verbose logging
  config.verbose = false

end
```

Put a route at the bottom of your routes.rb:

```ruby
match '*url' => 'cloud_assets#content'
```

This will allow cloud_assets to handle anything Rails
doesn't recognize.

In application_controller.rb:

```ruby
include CloudAssets
```

## Additional Configuration

If you are serving any non-trivial amount of remotely
sourced assets out of your Rails system, you'll want a cache.
FIXME: The cache currently uses dalli only. This should be
and can be configured more flexibly in the initializer.

To enable it, just define $dalli_cache somewhere in one of
your initializers.

## Usage

Set a remote layout for an HTML view by defining the URI to
the layout on the remote system, e.g.

```ruby
set_remote_layout '/templates/foo.html'
```

You can inject additional content into the elements of that
template, or override the interior of its elements, using CSS
selectors:

```ruby
inject_into_remote_layout '#notice' => flash[:notice]
override_remote_layout 'body' => yield
```

Finally, obtain and show the result (complete with rewrites
of CDN URLs and so on) with:

```ruby
apply_remote_layout
```

So a complete application layout would look something like this (Haml):

```
- set_default_remote_layout '/about/'
- inject_into_remote_layout 'head' => (render :partial => 'layouts/headers')
- unless yield.empty?
  - override_remote_layout '#content' => yield
!= apply_remote_layout
```

This loads the HTML of the remote "about" page, rewrites references to
localhost or the CDN as appropriate, injects Rails headers form the
headers partial into the HTML head element, and replaces the interior
of the element whose id is "content" -- say it's a div -- with the
yield of the Rails view that uses this layout.

## Fixups

The remote site likely was not designed to have its HTML repurposed and
rewritten on other sites. Sites following best practices *should* not
need any manual fixups. However, any number of hacks might produce HTML
that cloud_assets does not know how to rewrite. You have an opportunity
to fix these by adding a monkey-patch to your initializer:

```ruby
module CloudAssets
  def self.fixup_html(html)
    html.gsub 'something bad', 'something good'
  end
end
```

This method is applied immediately before the HTML is delivered to the
browser; you can do anything here that you like, but it should be
regarded as a hack. If the uncorrectable code is standards-compliant
and best practice, it would be good to submit a pull request so
cloud_assets can handle it. If not, it would be ideal to fix the
remote asset source -- e.g. remove hard-coded references or eliminate
unwarranted assumptions.
