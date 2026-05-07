# generic-administrate

`generic-administrate` は、Yummy Guide 系 Rails アプリで共通利用する
[`Administrate`](https://github.com/thoughtbot/administrate) 拡張をまとめた Rails
Engine です。

`Administrate` 本体を置き換えるものではなく、ダッシュボードの共通既定値、
フィルター UI、一覧表示 helper、共通 field などを再利用しやすくするための補助
gem です。

## 前提

- Ruby `>= 3.2.2`
- Rails `>= 7.0`, `< 7.2`
- Administrate `>= 0.19`, `< 0.21`
- `sprockets-rails`

## インストール

`Gemfile` に追加します。

```ruby
gem "generic-administrate"
```

その後、依存 gem をインストールします。

```bash
bundle install
```

## 提供するもの

- `YummyGuide::Administrate::ApplicationDashboard`
  - 一覧画面の既定ソートと固定列数の共通基底クラス
- `YummyGuide::Administrate::DefaultSorting`
  - dashboard 側の既定ソート設定を controller に反映する concern
- `YummyGuide::Administrate::DatetimeFilterParameters`
  - 日付、時、分の分割パラメータを 1 つの datetime 文字列へ正規化する concern
- `YummyGuide::Administrate::CollectionHelper`
  - 一覧テーブルの固定列数、リンク生成、action partial 解決を補助する helper
- `YummyGuide::Administrate::FilterFormHelper`
  - datetime フィルターや checkbox group の組み立てを補助する helper
- 共通 partial / assets
  - collection partial
  - filter form partial
  - `filter_form.js`
  - `sticky_left_columns.js`
  - `components.css`
- 共通 field
  - `YummyGuide::Administrate::Fields::JsonPrettyField`
  - `YummyGuide::Administrate::Fields::VersionItemField`
  - `YummyGuide::Administrate::Fields::VersionWhodunnitField`
  - `YummyGuide::Administrate::Fields::Area::PictureField`

## 利用方法

### Dashboard の基底クラス

共通の既定ソートと固定列数設定を使う場合は、dashboard を
`YummyGuide::Administrate::ApplicationDashboard` から継承します。

```ruby
class ApplicationDashboard < YummyGuide::Administrate::ApplicationDashboard
end
```

必要に応じて各 dashboard 側で上書きできます。

```ruby
class Admin::ArticleDashboard < ApplicationDashboard
  COLLECTION_ATTRIBUTES = %i[id title status created_at].freeze
  COLLECTION_SORTABLE_ATTRIBUTES = %i[id title status created_at].freeze
  INDEX_FIXED_COLUMNS_COUNT = 2

  def default_sorting_attribute
    :published_at
  end

  def default_sorting_direction
    :desc
  end
end
```

### Controller concern / helper

管理画面の基底 controller で共通 concern と helper を読み込みます。

```ruby
class Admin::ApplicationController < Administrate::ApplicationController
  include YummyGuide::Administrate::DefaultSorting
  include YummyGuide::Administrate::DatetimeFilterParameters

  helper YummyGuide::Administrate::CollectionHelper
  helper YummyGuide::Administrate::FilterFormHelper
end
```

### Collection partial

ホストアプリ側の `app/views/administrate/application/_collection.html.erb` から、
engine の共通 partial に委譲します。

```erb
<%= render "yummy_guide/administrate/administrate/application/collection",
           collection_presenter: collection_presenter,
           page: page,
           resources: resources,
           table_title: table_title,
           namespace: namespace,
           resource_class: resource_class,
           collection_field_name: collection_field_name %>
```

### Datetime filter

filter form の枠と datetime 入力 partial を組み合わせて利用できます。

```erb
<%= render "yummy_guide/administrate/filter_forms/frame",
           path: path,
           form: form,
           method: method,
           current_values: search_options do |f, values| %>
  <tr>
    <td><%= f.label :start_at, "開始日時" %></td>
    <td>
      <%= render "yummy_guide/administrate/filter_forms/datetime_field",
                 form_scope: form,
                 field_name: :start_at,
                 current_value: values["start_at"],
                 css_class: "#{form}_start_at" %>
    </td>
  </tr>
<% end %>
```

controller 側では、必要な filter key を指定して datetime パラメータを正規化します。

```ruby
def search_term
  resource_params = params[resource_name] || params[resource_name.to_sym] || {}
  raw_filters = resource_params[:search] || resource_params["search"] || {}

  normalized_filters = normalize_datetime_filter_params(
    raw_filters,
    keys: %i[start_at end_at]
  )

  normalized_filters
end
```

### Asset の読み込み

この engine の asset はホストアプリ側で明示的に読み込んでください。

```js
//= require yummy_guide_administrate/filter_form
//= require yummy_guide_administrate/sticky_left_columns
```

```scss
 *= require yummy_guide_administrate/components
```

### Custom field

dashboard から共通 field を利用できます。

```ruby
ATTRIBUTE_TYPES = {
  metadata: YummyGuide::Administrate::Fields::JsonPrettyField,
  item: YummyGuide::Administrate::Fields::VersionItemField.with_options(namespace: :admin),
  whodunnit: YummyGuide::Administrate::Fields::VersionWhodunnitField.with_options(
    namespace: :admin,
    user_class: "User"
  ),
  pictures: YummyGuide::Administrate::Fields::Area::PictureField
}.freeze
```

## 各 field の用途

### JsonPrettyField

JSON 文字列または JSON 互換オブジェクトを、整形済みの文字列として表示します。

### VersionItemField

PaperTrail の `item` や `reify` 結果をもとに、対象 resource のラベルと詳細画面への
リンクを表示します。`namespace` は `:admin` が既定です。

### VersionWhodunnitField

PaperTrail の `whodunnit` から操作ユーザーを解決して表示します。

- 既定では `User` クラスを参照します
- `user_class` で別クラスを指定できます
- `user_label` に proc を渡すと表示ラベルを上書きできます

### Area::PictureField

画像添付用の field です。Active Storage の添付オブジェクト、または `attachments`
を返すオブジェクトを前提としています。

必要に応じて以下の option を指定できます。

- `max_uploads`
- `input_name`
- `purge_input_name`
- `attachment_url`
- `preview_url`

## 参照

- Administrate 公式リポジトリ
  - <https://github.com/thoughtbot/administrate>
- Administrate gem ページ
  - <https://rubygems.org/gems/administrate>

## リリース手順

このリポジトリは `bundler/gem_tasks` を利用しているため、標準の gem リリースタスク
で公開できます。

1. `lib/yummy_guide/administrate/version.rb` の `VERSION` を更新する
2. 必要な変更を commit 済みの状態にする
3. 必要に応じて `bundle exec rake spec` で確認する
4. `bundle exec rake release` を実行する

`bundle exec rake release` を実行すると、現在の `VERSION` をもとに `v<version>` の
git tag を作成し、gem を build して `rubygems.org` へ push します。

事前に RubyGems への push 権限があること、ローカル環境で `gem push` が利用できる
ことを確認してください。

## 注意点

- asset は precompile 対象に追加されますが、ホストアプリ側での読み込み設定は別途必要です
- `VersionWhodunnitField` は対象ユーザー class や表示ラベルをアプリ事情に合わせて調整してください
- `Area::PictureField` の URL 解決は、必要なら option で明示的に上書きしてください
