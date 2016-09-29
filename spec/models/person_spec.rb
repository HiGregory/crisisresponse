require "rails_helper"
require "shared/analytics_token"
require "shared/person_validations"

RSpec.describe Person, type: :model do
  it_should_behave_like "it has an analytics token"

  describe "associations" do
    it { should have_many(:response_plans) }
    it { should have_many(:aliases).dependent(:destroy) }
    it { should have_many(:images).dependent(:destroy) }
  end

  describe "validations" do
    it_should_behave_like "a validated person"
  end

  describe ".update_visibility" do
    it "sets `visible` if # of recent incidents are below the threshold" do
      rms_person = create(:rms_person)
      person = rms_person.person
      person.update(visible: false)
      create_list(
        :incident,
        ENV.fetch("RECENT_CRISIS_INCIDENT_THRESHOLD").to_i,
        rms_person: rms_person,
      )

      Person.update_visibility

      person.reload
      expect(person).to be_visible
    end

    it "sets `visible` if there is an active response plan" do
      person = create(:person, visible: false)
      create(:response_plan, :approved, person: person)

      Person.update_visibility

      person.reload
      expect(person).to be_visible
    end

    it "unsets `visible` if # of recent incidents are below the threshold" do
      person = create(:rms_person).person
      person.update(visible: true)

      Person.update_visibility

      person.reload
      expect(person).not_to be_visible
    end
  end

  describe ".publicly_visible" do
    it "returns people who are visible" do
      visible = create(:person, visible: true)
      create(:person, visible: false)

      expect(Person.publicly_visible).to eq([visible])
    end
  end

  describe "#active_plan" do
    it "returns the most recent approved response plan" do
      person = create(:person)
      plans = [
        create(:response_plan, person: person, approved_at: 1.month.ago),
        create(:response_plan, person: person, approved_at: 1.week.ago),
        create(:response_plan, person: person, approved_at: nil, approver: nil),
      ]

      expect(person.active_plan).to eq(plans.second)
    end

    it "returns nil if there is no approved response plan" do
      person = create(:person)
      create(:response_plan, person: person, approved_at: nil, approver: nil)

      expect(person.active_plan).to eq(nil)
    end
  end

  describe "#display_name" do
    it "displays last name, first name, middle initial" do
      person = build(
        :person,
        first_name: "John",
        last_name: "Doe",
        middle_initial: "Q",
      )

      expect(person.display_name).to eq("Doe, John Q")
    end

    context "with a missing middle initial" do
      it "just displays first and last names" do
      person = build(
        :person,
        first_name: "John",
        last_name: "Doe",
        middle_initial: nil,
      )

      expect(person.display_name).to eq("Doe, John")
      end
    end
  end

  describe "#incidents_since" do
    it "returns the number of incidents since a given time" do
      rms_person = create(:rms_person)
      _old = create(:incident, reported_at: 3.days.ago, rms_person: rms_person)
      recent = create(:incident, reported_at: 1.day.ago, rms_person: rms_person)

      has_no_incidents = build_stubbed(:person)
      has_incidents = rms_person.person

      expect(has_no_incidents.incidents_since(2.days.ago)).to eq([])
      expect(has_incidents.incidents_since(2.days.ago)).to eq([recent])
    end
  end

  describe "#profile_image_url" do
    context "when no image is uploaded" do
      it "returns a URL to the default profile image" do
        person = Person.new

        expect(person.profile_image_url).to eq("/default_profile.png")
      end
    end
  end

  describe "#shorthand_description" do
    it "starts with a letter representing race" do
      expect(shorthand_for(race: "AFRICAN AMERICAN/BLACK")).to start_with("B")
      expect(shorthand_for(race: "AMERICAN INDIAN/ALASKAN NATIVE")).to start_with("I")
      expect(shorthand_for(race: "ASIAN (ALL)/PACIFIC ISLANDER")).to start_with("A")
      expect(shorthand_for(race: "UNKNOWN")).to start_with("U")
      expect(shorthand_for(race: "WHITE")).to start_with("W")
    end

    it "has a letter for gender in the second position" do
      expect(shorthand_for(sex: "Male")[1]).to eq("M")
      expect(shorthand_for(sex: "Female")[1]).to eq("F")
    end

    it "uses a character for other gender"

    it "Formats the height in feet and inches" do
      expect(shorthand_for(height_in_inches: 70)).to include("5'10\"")
    end

    it "includes the weight in pounds" do
      expect(shorthand_for(weight_in_pounds: 180)).to include("180 lb")
    end

    it "gracefully handles missing information" do
      expect(shorthand_for(height_in_inches: nil).chars.count("–")).to eq(1)
      expect(shorthand_for(weight_in_pounds: nil).chars.count("–")).to eq(1)
      expect(shorthand_for(height_in_inches: nil, weight_in_pounds: nil)).
        not_to include("–")
    end

    def shorthand_for(person_attrs)
      build(:person, person_attrs).shorthand_description
    end
  end

  describe "RMS fallbacks" do
    specify { expect_to_fallback_to_rms_person_for(:date_of_birth) }
    specify { expect_to_fallback_to_rms_person_for(:eye_color) }
    specify { expect_to_fallback_to_rms_person_for(:first_name) }
    specify { expect_to_fallback_to_rms_person_for(:hair_color) }
    specify { expect_to_fallback_to_rms_person_for(:height_in_inches) }
    specify { expect_to_fallback_to_rms_person_for(:last_name) }
    specify { expect_to_fallback_to_rms_person_for(:location_address, "foo") }
    specify { expect_to_fallback_to_rms_person_for(:location_name, "foo") }
    specify { expect_to_fallback_to_rms_person_for(:middle_initial) }
    specify { expect_to_fallback_to_rms_person_for(:race) }
    specify { expect_to_fallback_to_rms_person_for(:scars_and_marks, "foo") }
    specify { expect_to_fallback_to_rms_person_for(:sex) }
    specify { expect_to_fallback_to_rms_person_for(:weight_in_pounds) }

    specify { expect_identical_assignment_to_not_update_person(:date_of_birth, Date.today) }
    specify { expect_identical_assignment_to_not_update_person(:eye_color, "blue") }
    specify { expect_identical_assignment_to_not_update_person(:first_name, "Foo") }
    specify { expect_identical_assignment_to_not_update_person(:hair_color, "brown") }
    specify { expect_identical_assignment_to_not_update_person(:height_in_inches, 60) }
    specify { expect_identical_assignment_to_not_update_person(:last_name, "Foo") }
    specify { expect_identical_assignment_to_not_update_person(:location_address, "foo") }
    specify { expect_identical_assignment_to_not_update_person(:location_name, "foo") }
    specify { expect_identical_assignment_to_not_update_person(:middle_initial, "A") }
    specify { expect_identical_assignment_to_not_update_person(:race, "WHITE") }
    specify { expect_identical_assignment_to_not_update_person(:scars_and_marks, "foo") }
    specify { expect_identical_assignment_to_not_update_person(:sex, "Male") }
    specify { expect_identical_assignment_to_not_update_person(:weight_in_pounds, 200) }

    specify { expect_different_assignment_to_update_person(:date_of_birth, Date.today, 20.years.ago.to_date) }
    specify { expect_different_assignment_to_update_person(:eye_color, "blue", "brown") }
    specify { expect_different_assignment_to_update_person(:first_name, "Foo", "Bar") }
    specify { expect_different_assignment_to_update_person(:hair_color, "brown", "black") }
    specify { expect_different_assignment_to_update_person(:height_in_inches, 50, 60) }
    specify { expect_different_assignment_to_update_person(:last_name, "Foo", "Bar") }
    specify { expect_different_assignment_to_update_person(:location_address, "foo", "bar") }
    specify { expect_different_assignment_to_update_person(:location_name, "foo", "bar") }
    specify { expect_different_assignment_to_update_person(:race, "WHITE", "UNKNOWN") }
    specify { expect_different_assignment_to_update_person(:scars_and_marks, "foo", "bar") }
    specify { expect_different_assignment_to_update_person(:sex, "Male", "Female") }
    specify { expect_different_assignment_to_update_person(:weight_in_pounds, 200, 180) }

    def expect_to_fallback_to_rms_person_for(attribute, value = nil)
      factory_options = value ? { attribute => value } : {}
      person = build(:person)
      rms_person = build(:rms_person, factory_options)
      person.rms_person = rms_person
      person.assign_attributes(attribute => nil)

      actual = person.public_send(attribute)
      expected = rms_person.public_send(attribute)

      expect(actual).not_to be_nil
      expect(actual).to eq(expected)
    end

    def expect_identical_assignment_to_not_update_person(attribute, value)
      person = build(:person, attribute => nil)
      person.save(validate: false)
      create(:rms_person, person: person, attribute => value)

      expect do
        person.update(attribute => value)
      end.not_to change { person.reload.attributes[attribute.to_s] }
    end

    def expect_different_assignment_to_update_person(attribute, old, new)
      person = build(:person, attribute => nil)
      person.save(validate: false)
      create(:rms_person, person: person, attribute => old)

      expect { person.update(attribute => new) }.
        to change { person.reload.attributes[attribute.to_s] }.
        from(nil).
        to(new)
    end
  end
end
