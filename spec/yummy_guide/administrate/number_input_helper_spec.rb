# frozen_string_literal: true

require "spec_helper"
require "nokogiri"

RSpec.describe YummyGuide::Administrate::NumberInputHelper do
  subject(:helper_host) do
    Class.new do
      include ActionView::Context
      include ActionView::Helpers::FormHelper
      include ActionView::Helpers::FormTagHelper
      include ActionView::Helpers::OutputSafetyHelper
      include ActionView::Helpers::TagHelper
      include YummyGuide::Administrate::NumberInputHelper
    end.new
  end

  before do
    stub_const("SpecNumberInputResource", Class.new do
      extend ActiveModel::Naming
      include ActiveModel::Conversion

      attr_accessor :base_salary

      def persisted?
        false
      end
    end)
  end

  let(:resource) do
    SpecNumberInputResource.new.tap do |record|
      record.base_salary = "123.45"
    end
  end

  def fragment(html)
    Nokogiri::HTML.fragment(html)
  end

  describe "#number_field" do
    it "renders a decimal-friendly text input without number-only control attributes" do
      html = helper_host.number_field(
        :job_match,
        :base_salary,
        class: "payment-input",
        data: { role: "base-salary" },
        required: true,
        disabled: true,
        readonly: true,
        placeholder: "0.0",
        value: "100.5",
        min: 0,
        max: 999,
        step: "any",
        in: 1..10,
        within: 1..10
      )
      input = fragment(html).at_css("input")

      expect(input["type"]).to eq("text")
      expect(input["inputmode"]).to eq("decimal")
      expect(input["class"]).to eq("payment-input")
      expect(input["id"]).to eq("job_match_base_salary")
      expect(input["name"]).to eq("job_match[base_salary]")
      expect(input["value"]).to eq("100.5")
      expect(input["data-role"]).to eq("base-salary")
      expect(input["required"]).to eq("required")
      expect(input["disabled"]).to eq("disabled")
      expect(input["readonly"]).to eq("readonly")
      expect(input["placeholder"]).to eq("0.0")
      expect(input["min"]).to be_nil
      expect(input["max"]).to be_nil
      expect(input["step"]).to be_nil
    end

    it "keeps range fields as range inputs" do
      input = fragment(helper_host.range_field(:job_match, :base_salary, value: "50")).at_css("input")

      expect(input["type"]).to eq("range")
      expect(input["value"]).to eq("50")
    end
  end

  describe "#number_field_tag" do
    it "renders a decimal-friendly text input without number-only control attributes" do
      html = helper_host.number_field_tag(
        "job_match[base_salary]",
        "200.5",
        id: "base_salary",
        class: "payment-input",
        data: { role: "base-salary" },
        required: true,
        disabled: true,
        readonly: true,
        placeholder: "0.0",
        min: 0,
        max: 999,
        step: "any",
        in: 1..10,
        within: 1..10
      )
      input = fragment(html).at_css("input")

      expect(input["type"]).to eq("text")
      expect(input["inputmode"]).to eq("decimal")
      expect(input["id"]).to eq("base_salary")
      expect(input["name"]).to eq("job_match[base_salary]")
      expect(input["value"]).to eq("200.5")
      expect(input["class"]).to eq("payment-input")
      expect(input["data-role"]).to eq("base-salary")
      expect(input["required"]).to eq("required")
      expect(input["disabled"]).to eq("disabled")
      expect(input["readonly"]).to eq("readonly")
      expect(input["placeholder"]).to eq("0.0")
      expect(input["min"]).to be_nil
      expect(input["max"]).to be_nil
      expect(input["step"]).to be_nil
    end

    it "keeps range field tags as range inputs" do
      input = fragment(helper_host.range_field_tag("base_salary", "50")).at_css("input")

      expect(input["type"]).to eq("range")
      expect(input["value"]).to eq("50")
    end

    it "keeps explicit range type options as range inputs" do
      input = fragment(helper_host.number_field_tag("base_salary", "50", "type" => "range")).at_css("input")

      expect(input["type"]).to eq("range")
      expect(input["value"]).to eq("50")
    end
  end

  describe "form builder integration" do
    it "routes f.number_field through the helper override" do
      form_builder = ActionView::Helpers::FormBuilder.new(:job_match, resource, helper_host, {})
      input = fragment(form_builder.number_field(:base_salary)).at_css("input")

      expect(input["type"]).to eq("text")
      expect(input["inputmode"]).to eq("decimal")
      expect(input["value"]).to eq("123.45")
    end

    it "keeps f.range_field as a range input" do
      form_builder = ActionView::Helpers::FormBuilder.new(:job_match, resource, helper_host, {})
      input = fragment(form_builder.range_field(:base_salary, value: "50")).at_css("input")

      expect(input["type"]).to eq("range")
      expect(input["value"]).to eq("50")
    end
  end
end
