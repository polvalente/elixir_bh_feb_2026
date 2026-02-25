defmodule BeamstagramWeb.ImageProcessingLive do
  use BeamstagramWeb, :live_view

  defmodule FilterParams do
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field(:filter, Ecto.Enum,
        values: [nil, :gaussian_blur, :uniform_blur, :sharpen, :tint],
        default: nil
      )

      field(:tint_r, :integer, default: 255)
      field(:tint_g, :integer, default: 255)
      field(:tint_b, :integer, default: 255)
      field(:tint_alpha, :float, default: 0.2)

      field(:kernel_size, :integer, default: 3)
      field(:sigma, :float, default: 1.0)

      field(:blur_kernel, Ecto.Enum,
        values: [:gaussian_blur, :uniform_blur],
        default: :gaussian_blur
      )
    end

    def changeset(data \\ %__MODULE__{}, params) do
      params = params |> Enum.reject(fn {_k, v} -> is_nil(v) end) |> Map.new()

      Ecto.Changeset.cast(data, params, [
        :filter,
        :kernel_size,
        :sigma,
        :blur_kernel,
        :tint_r,
        :tint_g,
        :tint_b,
        :tint_alpha
      ])
    end

    defimpl String.Chars do
      def to_string(%FilterParams{} = filter_params) do
        case filter_params.filter do
          nil ->
            "None"

          :gaussian_blur ->
            "Gaussian Blur (#{filter_params.kernel_size}x#{filter_params.kernel_size}, #{filter_params.sigma})"

          :uniform_blur ->
            "Uniform Blur (#{filter_params.kernel_size}x#{filter_params.kernel_size})"

          :sharpen ->
            "Sharpen (#{filter_params.blur_kernel}) #{filter_params.kernel_size}x#{filter_params.kernel_size} #{if(filter_params.blur_kernel == :gaussian_blur, do: ", #{filter_params.sigma}", else: "")}"

          :tint ->
            "Tint"
        end
      end
    end
  end

  def mount(_params, _session, socket) do
    changeset = FilterParams.changeset(%{})

    filter_params = Ecto.Changeset.apply_changes(changeset)

    filter_form =
      to_form(changeset, as: :filter_form)

    filter_options = [
      None: nil,
      "Gaussian Blur": :gaussian_blur,
      "Uniform Blur": :uniform_blur,
      Sharpen: :sharpen,
      Tint: :tint
    ]

    blur_kernel_options = [
      "Gaussian Blur": :gaussian_blur,
      "Uniform Blur": :uniform_blur
    ]

    {:ok,
     assign(socket,
       filter_form: filter_form,
       filter_options: filter_options,
       blur_kernel_options: blur_kernel_options,
       filter_params: filter_params
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="flex items-center justify-center" id="webcam-container" phx-hook="WebcamHook">
      <video
        data-filter-kind={@filter_params.filter}
        id="webcam-video"
        width="640"
        height="480"
        autoplay
      >
      </video>
      <canvas style="display: none" id="webcam-canvas" width="640" height="480"></canvas>
      <canvas id="webcam-output" width="640" height="480"></canvas>
    </div>

    <.form for={@filter_form} phx-change="update_filter">
      <.label for="filter">Filter</.label>
      <.input type="select" name="filter" value={@filter_params.filter} options={@filter_options} />

      <div :if={@filter_params.filter in [:gaussian_blur, :uniform_blur, :sharpen]}>
        <.label for="kernel_size">Kernel Size</.label>
        <.input type="number" name="kernel_size" value={@filter_params.kernel_size} />
      </div>

      <div :if={@filter_params.filter in [:gaussian_blur, :sharpen]}>
        <.label for="sigma">Sigma</.label>
        <.input type="range" name="sigma" value={@filter_params.sigma} step="0.5" min="0.1" max="50" />
      </div>

      <div :if={@filter_params.filter == :sharpen}>
        <.label for="blur_kernel">Blur Kernel</.label>
        <.input
          type="select"
          name="blur_kernel"
          value={@filter_params.blur_kernel}
          options={@blur_kernel_options}
          disabled={@filter_params.filter != :sharpen}
        />
      </div>

      <div :if={@filter_params.filter == :tint}>
        <.label for="tint_r">Tint Red</.label>
        <.input
          type="range"
          name="tint_r"
          value={@filter_params.tint_r}
          step="1"
          min="0"
          max="255"
        />

        <.label for="tint_g">Tint Green</.label>
        <.input
          type="range"
          name="tint_g"
          value={@filter_params.tint_g}
          step="1"
          min="0"
          max="255"
        />

        <.label for="tint_b">Tint Blue</.label>
        <.input
          type="range"
          name="tint_b"
          value={@filter_params.tint_b}
          step="1"
          min="0"
          max="255"
        />

        <.label for="tint_alpha">Tint Alpha</.label>
        <.input
          type="range"
          name="tint_alpha"
          value={@filter_params.tint_alpha}
          step="0.1"
          min="0"
          max="1"
        />
      </div>
    </.form>
    """
  end

  def handle_event("update_filter", %{"_target" => [target]} = params, socket) do
    value = params[target]

    changeset =
      FilterParams.changeset(socket.assigns.filter_params, %{target => value})

    filter_form = to_form(changeset, as: :filter_form)
    filter_params = Ecto.Changeset.apply_changes(changeset)

    {:noreply, assign(socket, filter_params: filter_params, filter_form: filter_form)}
  end

  def handle_event("process_frame", %{"data" => base64_data}, socket) do
    filter_params = socket.assigns.filter_params

    result =
      base64_data
      |> Base.decode64!()
      |> Beamstagram.Filters.apply_filter(Map.from_struct(filter_params))
      |> Base.encode64()

    {:noreply, push_event(socket, "frame_processed", %{data: result})}
  end
end
