defmodule SEO.OpenGraph do
  @moduledoc """
  Build OpenGraph tags. This is destined for Facebook, Google, Twitter, and Slack.

  ## Basic Metadata

  To turn your web pages into graph objects, you need to add basic metadata to your page. We've based the initial version of the protocol on RDFa which means that you'll place additional <meta> tags in the <head> of your web page. The four required properties for every page are:

  - `og:title` - The title of your object as it should appear within the graph, e.g., "The Rock".
  - `og:type` - The type of your object, e.g., "article". Depending on the type you specify, other properties may also be required.
  - `og:image` - An image URL which should represent your object within the graph.
  - `og:url` - The canonical URL of your object that will be used as its permanent ID in the graph, e.g., "https://www.imdb.com/title/tt0117500/".

  As an example, the following is the Open Graph protocol markup for The Rock on IMDB:

      <html prefix="og: https://ogp.me/ns#">
      <head>
      <title>The Rock (1996)</title>
      <meta property="og:title" content="The Rock" />
      <meta property="og:type" content="video.movie" />
      <meta property="og:url" content="https://www.imdb.com/title/tt0117500/" />
      <meta property="og:image" content="https://ia.media-imdb.com/images/rock.jpg" />
      ...
      </head>
      ...
      </html>

  ## Optional Metadata

  The following properties are optional for any object and are generally recommended:

  - `og:audio` - A URL to an audio file to accompany this object.
  - `og:description` - A one to two sentence description of your object.
  - `og:determiner` - The word that appears before this object's title in a sentence. An enum of (a, an, the, "", auto).
  If auto is chosen, the consumer of your data should chose between "a" or "an". Default is "" (blank).
  - `og:locale` - The locale these tags are marked up in. Of the format language_TERRITORY. Default is en_US.
  - `og:locale:alternate` - An array of other locales this page is available in.
  - `og:site_name` - If your object is part of a larger web site, the name which should be displayed for the overall
  site. e.g., "IMDb".
  - `og:video` - A URL to a video file that complements this object.

  ## Additional Resources

  https://developers.google.com/search/docs/appearance/structured-data/intro-structured-data
  https://developers.facebook.com/docs/sharing/webmasters/
  https://developer.twitter.com/en/docs/tweets/optimize-with-cards/overview/markup
  https://developer.twitter.com/en/docs/tweets/optimize-with-cards/overview/abouts-cards
  https://api.slack.com/reference/messaging/link-unfurling#classic_unfurl
  """

  ## TODO
  # - Tokenizer that turns HTML into sentences. re: https://github.com/wardbradt/HTMLST

  defstruct [
    :title,
    :type_detail,
    :image,
    :url,
    :audio,
    :locale,
    :locale_alternate,
    :site_name,
    :video,
    type: :website,
    description: "",
    determiner: :blank
  ]

  @type t :: %__MODULE__{
          title: String.t(),
          type: open_graph_type(),
          type_detail: type_detail(),
          url: URI.t() | String.t(),
          description: String.t() | nil,
          determiner: open_graph_determiner(),
          image: String.t() | SEO.OpenGraph.Image.t() | nil,
          audio: String.t() | SEO.OpenGraph.Audio.t() | nil,
          video: String.t() | SEO.OpenGraph.Video.t() | nil,
          locale: language_territory() | nil,
          locale_alternate: language_territory() | list(language_territory()) | nil,
          site_name: String.t() | nil
        }

  @typedoc "language code and territory code, eg: en_US"
  @type language_territory :: String.t()
  @type type_detail ::
          SEO.OpenGraph.Article.t()
          | SEO.OpenGraph.Profile.t()
          | SEO.OpenGraph.Book.t()
          | nil

  @typedoc """
  The word that appears before this object's title in a sentence. If `:auto` is chosen, the consumer of your data should
  chose between "a" or "an".
  """
  @type open_graph_determiner :: :a | :an | :the | :auto | :blank

  @type open_graph_type :: :article | :book | :profile | :website

  @config Application.compile_env(:seo, SEO.OpenGraph, [])
  def config, do: @config

  def build(map) when is_map(map) do
    %SEO.OpenGraph{}
    |> struct(Map.merge(Enum.into(@config, %{}), map))
    |> SEO.OpenGraph.build_type_detail(map)
  end

  def build(keyword) when is_list(keyword) do
    %SEO.OpenGraph{}
    |> struct(Keyword.merge(@config, keyword))
    |> SEO.OpenGraph.build_type_detail(keyword)
  end

  @doc false
  def build_type_detail(%{type: :website} = og, _attrs), do: og

  def build_type_detail(%{type: :article} = og, attrs) do
    %{og | type_detail: SEO.OpenGraph.Article.build(attrs)}
  end

  def build_type_detail(%{type: :book} = og, attrs) do
    %{og | type_detail: SEO.OpenGraph.Book.build(attrs)}
  end

  def build_type_detail(%{type: :profile} = og, attrs) do
    %{og | type_detail: SEO.OpenGraph.Profile.build(attrs)}
  end

  defp to_iso8601(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_iso8601(ndt)
  defp to_iso8601(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp to_iso8601(%Date{} = d), do: Date.to_iso8601(d)

  use Phoenix.Component

  attr(:og, :any, required: true)

  def meta(assigns) do
    ~H"""
    <%= if @og.site_name do %>
    <meta property="og:site_name" content={@og.site_name} />
    <% end %>
    <meta property="og:title" content={@og.title} />
    <meta property="og:type" content={@og.type} />
    <.url property="og:url" content={@og.url} />
    <meta property="og:description" content={@og.description} />
    <%= if @og.locale do %>
    <meta property="og:locale" content={@og.locale} />
    <% end %>
    <%= for locale <- List.wrap(@og.locale_alternate) do %>
    <meta property="og:locale:alternate" content={locale} />
    <% end %>
    <%= if @og.type == :book do %>
    <.book content={@og.type_detail} />
    <% end %>
    <%= if @og.type == :article do %>
    <.article content={@og.type_detail} />
    <% end %>
    <%= if @og.type == :profile do %>
    <.profile content={@og.type_detail} />
    <% end %>
    <%= for image <- List.wrap(@og.image) do %>
    <.image content={image} />
    <% end %>
    <%= for audio <- List.wrap(@og.audio) do %>
    <.audio content={audio} />
    <% end %>
    <%= for video <- List.wrap(@og.video) do %>
    <.video content={video} />
    <% end %>
    """
  end

  attr(:property, :string, required: true)
  attr(:content, :any, required: true)

  def url(assigns) do
    case assigns[:content] do
      nil ->
        ~H""

      %URI{} ->
        ~H"""
        <meta property={@property} content={"#{@content}"} />
        """

      url when is_binary(url) ->
        ~H"""
        <meta property={@property} content={@content} />
        """
    end
  end

  attr(:content, :any, required: true)

  def article(assigns) do
    ~H"""
    <%= if @content.published_time do %>
    <meta property="article:published_time" content={to_iso8601(@content.published_time)} />
    <% end %>
    <%= if @content.modified_time do %>
    <meta property="article:modified_time" content={to_iso8601(@content.modified_time)} />
    <% end %>
    <%= if @content.expiration_time do %>
    <meta property="article:expiration_time" content={to_iso8601(@content.expiration_time)} />
    <% end %>
    <%= if @content.section do %>
    <meta property="article:section" content={@content.section} />
    <% end %>
    <%= for author <- List.wrap(@content.author) do %>
    <meta property="article:author" content={author} />
    <% end %>
    <%= for tag <- List.wrap(@content.tag) do %>
    <meta property="article:tag" content={tag} />
    <% end %>
    """
  end

  attr(:content, :any, required: true)

  def book(assigns) do
    ~H"""
    <%= if @content.release_date do %>
    <meta property="book:release_date" content={to_iso8601(@content.release_date)} />
    <% end %>
    <%= if @content.isbn do %>
    <meta property="book:isbn" content={@content.isbn} />
    <% end %>
    <%= for author <- List.wrap(@content.author) do %>
    <meta property="book:author" content={author} />
    <% end %>
    <%= for tag <- List.wrap(@content.tag) do %>
    <meta property="book:tag" content={tag} />
    <% end %>
    """
  end

  attr(:content, :any, required: true)

  def profile(assigns) do
    ~H"""
    <%= if @content.first_name do %>
    <meta property="profile:first_name" content={@content.first_name} />
    <% end %>
    <%= if @content.last_name do %>
    <meta property="profile:last_name" content={@content.last_name} />
    <% end %>
    <%= if @content.username do %>
    <meta property="profile:username" content={@content.username} />
    <% end %>
    <%= if @content.gender do %>
    <meta property="profile:gender" content={@content.gender} />
    <% end %>
    """
  end

  attr(:content, :any, required: true)

  def image(assigns) do
    case assigns[:content] do
      %SEO.OpenGraph.Image{} ->
        ~H"""
        <meta property="og:image" content={@content.url} />
        <%= if @content.secure_url do %>
        <meta property="og:image:secure_url" content={@content.secure_url} />
        <% end %>
        <%= if @content.type do %>
        <meta property="og:image:type" content={@content.type} />
        <% end %>
        <%= if @content.width do %>
        <meta property="og:image:width" content={@content.width} />
        <% end %>
        <%= if @content.height do %>
        <meta property="og:image:height" content={@content.height} />
        <% end %>
        <%= if @content.alt do %>
        <meta property="og:image:alt" content={@content.alt} />
        <% end %>
        """

      _url ->
        ~H"""
        <.url property="og:image" content={@content} />
        """
    end
  end

  attr(:content, :any, required: true)

  def video(assigns) do
    case assigns[:content] do
      %SEO.OpenGraph.Video{} ->
        ~H"""
        <meta property="og:video" content={@content.url} />
        <%= if @content.secure_url do %>
        <meta property="og:video:secure_url" content={@content.secure_url} />
        <% end %>
        <%= if @content.mime do %>
        <meta property="og:video:type" content={@content.mime} />
        <% end %>
        <%= if @content.width do %>
        <meta property="og:video:width" content={@content.width} />
        <% end %>
        <%= if @content.height do %>
        <meta property="og:video:height" content={@content.height} />
        <% end %>
        <%= if @content.alt do %>
        <meta property="og:video:alt" content={@content.alt} />
        <% end %>
        """

      _url ->
        ~H"""
        <.url property="og:video" content={@content} />
        """
    end
  end

  attr(:content, :any, required: true)

  def audio(assigns) do
    case assigns[:content] do
      %SEO.OpenGraph.Audio{} ->
        ~H"""
        <meta property="og:audio" content={@content.url} />
        <%= if @content.secure_url do %>
        <meta property="og:audio:secure_url" content={@content.secure_url} />
        <% end %>
        <%= if @content.mime do %>
        <meta property="og:audio:type" content={@content.mime} />
        <% end %>
        """

      _url ->
        ~H"""
        <.url property="og:audio" content={@content} />
        """
    end
  end
end