# yummy-guide-generic-administrate

`yummy-guide-generic-administrate` は、Yummy Guide 系 Rails アプリで共通利用する
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
gem "yummy-guide-generic-administrate"
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
- `YummyGuide::Administrate::DatetimeInputHelper`
  - 管理画面フォーム用の date + time 入力 helper
- 共通 partial / assets
  - collection partial
  - fixed table header partial
  - filter form partial
  - `clipboards.js`
  - `datetime_input.js`
  - `fixed_submit_actions.js`
  - `filter_form.js`
  - `sticky_left_columns.js`
  - `sticky_table_headers.js`
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
  helper YummyGuide::Administrate::DatetimeInputHelper
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

### 固定ヘッダーの設定

#### 1. 最小構成

gem 付属の collection partial をそのまま使う場合、table wrapper と table 本体に
必要な `data-*` 属性はすでに入っています。そのため、JS / CSS を読み込めば固定
ヘッダーは自動で有効になります。

内部的には以下のような構造になります。

```erb
<div class="scroll-table" data-fixed-header-scroll>
  <table
    aria-labelledby="<%= table_title %>"
    data-fixed-columns-count="<%= yummy_guide_administrate_collection_table_fixed_columns_count(page: page, collection_presenter: collection_presenter) %>"
    data-fixed-header-source
  >
    ...
  </table>
</div>
```

#### 2. ヘッダー位置を明示したい場合

固定ヘッダーの表示位置をページ上部の特定箇所に合わせたい場合は、
`data-fixed-table-header` を持つ slot を `.main-content` 配下に置きます。
gem には専用 partial があります。

```erb
<header class="main-content__header">
  <h1 id="page-title">Articles</h1>
  <%= render "yummy_guide/administrate/administrate/application/fixed_table_header" %>
</header>

<section class="main-content__body main-content__body--flush">
  <%= render "yummy_guide/administrate/administrate/application/collection",
             collection_presenter: collection_presenter,
             page: page,
             resources: resources,
             table_title: "page-title",
             namespace: :admin,
             resource_class: resource_class,
             collection_field_name: resource_name %>
</section>
```

`fixed_table_header` partial 自体は以下の 1 行です。

```erb
<div class="yummy-guide-administrate-fixed-table-header" data-fixed-table-header hidden></div>
```

この slot を置かない場合でも、JS が table の直前に自動生成します。配置を制御
したいときだけ明示してください。desktop では LMJ と同じく、`main-content__body--flush`
と組み合わせることで fixed header のクリップ幅が一覧 body と揃い、一覧 wrapper
自体には縦スクロールを持たせません。

#### 3. 自前の table partial を使う場合

独自の collection partial を書く場合は、少なくとも以下を満たしてください。

- 横スクロール wrapper に `data-fixed-header-scroll` を付ける
- table に `data-fixed-header-source` を付ける
- table に `data-fixed-columns-count` を付ける
- header の `aria-labelledby` がページタイトルと対応している

```erb
<%= render "yummy_guide/administrate/administrate/application/fixed_table_header" %>

<div class="scroll-table" data-fixed-header-scroll>
  <table
    aria-labelledby="page-title"
    data-fixed-header-source
    data-fixed-columns-count="<%= yummy_guide_administrate_collection_table_fixed_columns_count(page: page, collection_presenter: collection_presenter) %>"
  >
    <thead>
      <tr>
        <th>ID</th>
        <th>Name</th>
        <th class="sticky actions-column">Actions</th>
      </tr>
    </thead>
    <tbody>
      <% resources.each do |resource| %>
        <tr>
          <td><%= resource.id %></td>
          <td><%= resource.name %></td>
          <td class="sticky actions-column">
            <%= link_to "Show", [:admin, resource] %>
          </td>
        </tr>
      <% end %>
    </tbody>
  </table>
</div>
```

`sticky actions-column` を action 列に付けると、右端列も固定できます。
左端の固定列数は dashboard 側の `INDEX_FIXED_COLUMNS_COUNT` で制御します。

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

### Datetime input helper

通常フォームで日付と時刻を分けた入力 UI を使う場合は、`DatetimeInputHelper`
を読み込んで `admin_datetime_*` helper を使います。既存の LMJ 互換として、
helper 名は `admin_` prefix のまま提供しています。

```erb
<%= admin_datetime_field_tag(
      "coupon[expiration_date]",
      @coupon.expiration_date,
      required: true,
      default_current_time: @coupon.new_record?
    ) %>

<%= admin_split_datetime_field_tag(
      date_name: "coupon[expiration_date_date]",
      hour_name: "coupon[expiration_date_hour]",
      minute_name: "coupon[expiration_date_minute]",
      value: @coupon.expiration_date
    ) %>

<%= admin_date_and_time_field_tag(
      date_name: "reservation_task[due_date_on]",
      time_name: "reservation_task[due_time]",
      value: @reservation_task.due_at
    ) %>

<%= admin_time_field_tag("option[valid_from_time]", @option.valid_from_time) %>
```

`datetime_input.js` は visible な date / time 入力と hidden の送信値を同期し、
不正な日付や時刻の submit を抑止します。

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
//= require yummy_guide_administrate/clipboards
//= require yummy_guide_administrate/datetime_input
//= require yummy_guide_administrate/fixed_submit_actions
//= require yummy_guide_administrate/filter_form
//= require yummy_guide_administrate/sticky_left_columns
//= require yummy_guide_administrate/sticky_table_headers
```

```scss
 *= require yummy_guide_administrate/components
```

### 固定更新ボタン

管理画面の `new` / `edit` 系フォームでは、submit セクションを画面下に固定表示できます。
この機能は `fixed_submit_actions.js` と `components.css` に含まれる style によって動作します。

#### 固定対象を明示指定する場合

固定したい submit セクションに `data-fixed-submit-actions="true"` を付けます。

```erb
<div class="form-actions" data-fixed-submit-actions="true">
  <%= f.submit %>
</div>
```

この指定がある場合、gem はその submit セクションを最優先で固定対象にします。
1 ページに複数フォームがあっても、明示指定した submit セクションだけが固定表示されます。

#### 設定しなかった場合の挙動

`data-fixed-submit-actions="true"` が 1 件もない場合、gem は admin の `new` / `edit`
ページで submit セクションを自動選択します。

- 各フォーム内の `.form-actions` / `.form_submit` を候補にする
- `form-actions--top` が付いた上部 submit は除外する
- `data-fixed-submit-exclude="true"` が付いた submit セクションも除外する
- 各フォームでは最後の submit セクションだけを候補にする
- 複数フォームがあるページでは、現在表示中のフォームに対応する submit を固定する

上部 submit と下部 submit の両方があるフォームでは、下部 submit が自動で選ばれます。

#### fixed 帯に表示されるボタン

fixed 帯には submit セクションのクローンを表示します。

- 元のフォーム内ボタンの見た目は変更しない
- fixed 帯にだけ大きいボタンサイズを適用する
- 1 つの submit セクションに複数 submit ボタンがある場合は全部表示する

#### 自動選択から除外したい場合

自動選択の候補から外したい submit セクションには、`data-fixed-submit-exclude="true"`
を付けます。

```erb
<div class="form-actions" data-fixed-submit-exclude="true">
  <%= f.submit "Preview" %>
</div>
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
