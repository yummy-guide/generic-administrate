# frozen_string_literal: true

RSpec.describe "filter form assets" do
  let(:javascript_source) do
    File.read(File.expand_path("../../../app/assets/javascripts/yummy_guide_administrate/filter_form.js", __dir__))
  end

  let(:clear_form_fields_source) do
    javascript_source[/function clearFormFields\(formEl\) \{.*?\n  \}\n/m]
  end

  # フォーム全体のClearでフィルター行内のhidden値（Location等）もクリアし、フォーム全体のhiddenは保持することを静的に確認する
  it "clears hidden fields inside filter rows only" do
    expect(clear_form_fields_source).not_to be_nil
    expect(clear_form_fields_source).not_to include('fieldEl.type === "hidden" || fieldEl.type === "submit"')
    expect(clear_form_fields_source).to include('if (!fieldEl.closest(".filter_table")) return;')
  end

  # フォーム全体のClearでも行単位のClearと同じく、空の選択肢がないselectは"all"を選択することを静的に確認する
  it "resets selects the same way as the per-row clear" do
    expect(clear_form_fields_source).to include("resetSelectControl(fieldEl);")
    expect(javascript_source).to include('rowEl.querySelectorAll("select").forEach(resetSelectControl);')
    expect(javascript_source).to include('selectEl.value = "all";')
  end
end
