# generic-administrate

Shared `Administrate` extensions extracted from `Last Minute Japan` for reuse in
other Yummy Guide Rails applications.

## What It Provides

- Shared base dashboard defaults for sort and fixed columns
- Collection partial helpers and a reusable collection partial
- Filter form helpers, partials, and frontend assets
- Shared field classes for:
  - `json_pretty_field`
  - `version_item_field`
  - `version_whodunnit_field`
  - `area/picture_field`

## Usage

### Base dashboard

```ruby
class ApplicationDashboard < YummyGuide::Administrate::ApplicationDashboard
end
```

### Controller concerns

```ruby
class Admin::ApplicationController < Administrate::ApplicationController
  include YummyGuide::Administrate::DefaultSorting
  include YummyGuide::Administrate::DatetimeFilterParameters
  helper YummyGuide::Administrate::CollectionHelper
  helper YummyGuide::Administrate::FilterFormHelper
end
```

### Shared collection partial

Create a host-side delegating partial such as
`app/views/administrate/application/_collection.html.erb`:

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

### Shared filter frame

```erb
<%= render "yummy_guide/administrate/filter_forms/frame",
           path: path,
           form: form,
           method: method,
           current_values: search_options do |f, values| %>
  <tr>
    <td><%= f.label :start_date, "Start date" %></td>
    <td>
      <%= render "yummy_guide/administrate/filter_forms/datetime_field",
                 form_scope: form,
                 field_name: :start_date,
                 current_value: values["start_date"],
                 css_class: "#{form}_start_date" %>
    </td>
  </tr>
<% end %>
```

### Shared assets

Import the engine assets explicitly in the host app:

```js
//= require yummy_guide_administrate/filter_form
//= require yummy_guide_administrate/sticky_left_columns
```

```scss
 *= require yummy_guide_administrate/components
```

