class Shortener::ShortenedUrlsController < ApplicationController
  include ActionController::StrongParameters
  include ActionController::Redirecting
  include ActionController::Instrumentation
  include Rails.application.routes.url_helpers
  include Shortener

  def show
    slug = ShortenedUrl.extract_token(params[:id])
    shortened_url = ShortenedUrl.fetch_with_token(token: slug, additional_params: params, track: false)

    if shortened_url[:shortened_url]
      redirect_to shortened_url[:url]
    else
      not_found
    end
  end

  def create
    long_url_param = params[:url]
    long_url = ShortenedUrlExt.normalize_url(long_url_param)

    custom_slug_param = params[:custom_slug]

    if custom_slug_param
      custom_slug = ShortenedUrl.extract_token(custom_slug_param)
      handle_new_shortened_url(ShortenedUrlExt.create_with_custom_slug(long_url, custom_slug))
    else
      handle_new_shortened_url(ShortenedUrlExt.create_with_dynamic_slug(long_url))
    end
  end

  def destroy
    slug = params[:id]
    shortened_url = ShortenedUrlExt.find_unexpired_shortened_url_by_slug(slug)

    if (shortened_url)
      now = Time.current.to_s
      render :status => 200 if shortened_url.update(expires_at: now)
    else
      not_found
    end
  end

  # #########################
  #        private
  # #########################

  private def handle_new_shortened_url(shortened_url_result)
    if (shortened_url_result.error_message)
      render json: {message: shortened_url_result.error_message}, status: :unprocessable_entity
    else
      if (shortened_url_result.shortened_url)
        url = absolute_shortened_url(shortened_url_result.shortened_url.unique_key)
        render json: {short_url: url}
      else
        application_error
      end
    end
  end

  private def absolute_shortened_url(slug)
    url_for({controller: "/shortener/shortened_urls", action: :show, id: slug, only_path: false})
  end
end
