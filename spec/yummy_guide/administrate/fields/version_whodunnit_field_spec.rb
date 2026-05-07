# frozen_string_literal: true

require "spec_helper"

RSpec.describe YummyGuide::Administrate::Fields::VersionWhodunnitField do
  let(:user_class) do
    Class.new do
      def self.find_by(id:)
        return unless id == 5

        Struct.new(:id, :full_name) do
          def self.model_name
            ActiveModel::Name.new(self, nil, "User")
          end
        end.new(5, "Test User")
      end
    end
  end

  def build_field(data)
    described_class.new(:whodunnit, data, :show, resource: Object.new, user_class: user_class)
  end

  it "uses the resolved user label when found" do
    expect(build_field(5).label).to eq("Test User")
  end

  it "falls back to a generic label when the user is missing" do
    expect(build_field(99).label).to eq("User #99")
  end
end
