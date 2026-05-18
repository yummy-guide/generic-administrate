# frozen_string_literal: true

require "spec_helper"
require "nokogiri"

RSpec.describe "fields/number/_form" do
  subject(:fragment) { Nokogiri::HTML.fragment(rendered) }

  before do
    stub_const("SpecNumberFormResource", Class.new do
      extend ActiveModel::Naming
      include ActiveModel::Conversion

      attr_accessor :base_salary

      def persisted?
        false
      end
    end)
  end

  let(:rendered) do
    view.render(
      partial: "fields/number/form",
      locals: { f: form_builder, field: field }
    )
  end

  let(:view) do
    ActionView::Base.with_empty_template_cache.new(
      ActionView::LookupContext.new([File.expand_path("../../../../app/views", __dir__)]),
      {},
      nil
    )
  end

  let(:resource) { SpecNumberFormResource.new }
  let(:form_builder) { ActionView::Helpers::FormBuilder.new(:job_match, resource, view, {}) }
  let(:field) { Struct.new(:attribute).new(:base_salary) }

  it "renders number attributes as a decimal-friendly text input" do
    input = fragment.at_css('input[name="job_match[base_salary]"]')

    expect(input["type"]).to eq("text")
    expect(input["inputmode"]).to eq("decimal")
    expect(rendered).not_to include('type="number"')
  end
end
