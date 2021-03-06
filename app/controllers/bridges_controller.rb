# frozen_string_literal: true

class BridgesController < ApplicationController
  before_action :authorize_request
  before_action :set_bridge, except: %i[index create]

  def index
    @bridges = @current_user.bridges.all.map(&:add_event_info)

    render_message message: { bridges: @bridges }
  end

  def show
    render(
      json: { bridge: @bridge },
      include: {
        headers: {},
        environment_variables: { except: :value },
        events: { only: %i[completed completed_at id status_code] }
      },
      status: :ok
    )
  end

  def create
    @bridge = Bridge.new(bridge_params)
    @bridge.user = @current_user

    if @bridge.save
      render_message message: { slug: @bridge.slug }, status: :created
    else
      render_message message: @bridge.errors, status: :bad_request
    end
  end

  def update
    if @bridge.update bridge_params
      render_message
    else
      render_message message: @bridge.errors, status: :bad_request
    end
  end

  def destroy
    @bridge.destroy
    render_message
  end

  def activate
    @bridge.update active: true
    render_message
  end

  def deactivate
    @bridge.update active: false
    render_message
  end

  protected

  # rubocop:disable Metrics/MethodLength
  def bridge_params
    params.require(:bridge).permit(
      :active,
      :title,
      :http_method,
      :retries,
      :delay,
      :slug,
      :outbound_url,
      :payload,
      data: %i[payload test_payload],
      headers_attributes: %i[id key value],
      environment_variables_attributes: %i[id key value]
    )
  end
  # rubocop:enable Metrics/MethodLength

  def set_bridge
    @bridge = Bridge.includes(
      :events,
      :headers,
      :environment_variables
    ).find_by(slug: (params[:bridge_slug] || params[:slug]), user_id: @current_user.id)
    render_message status: :unprocessable_entity unless @bridge
  end
end
