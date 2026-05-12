# frozen_string_literal: true

module YummyGuide
  module Administrate
    module DatetimeInputHelper
      def admin_datetime_field_tag(name, value = nil, id: nil, required: false, max: nil, min: nil, input_class: nil, wrapper_class: nil, data: {}, default_current_time: false)
        parts = admin_datetime_value_parts(value, default_current_time: default_current_time)
        admin_render_datetime_input(
          mode: "combined",
          parts: parts,
          required: required,
          wrapper_class: wrapper_class,
          target_inputs: [
            {
              type: "hidden",
              name: name,
              id: id || admin_datetime_dom_id(name),
              value: admin_datetime_combined_value(parts),
              class: input_class,
              min: min,
              max: max,
              data: { admin_datetime_target: "combined" }.merge(data || {})
            }
          ],
          calendar_min: admin_datetime_date_boundary(min),
          calendar_max: admin_datetime_date_boundary(max)
        )
      end

      def admin_split_datetime_field_tag(date_name:, hour_name:, minute_name:, value: nil, date_id: nil, hour_id: nil, minute_id: nil, required: false, wrapper_class: nil, default_current_time: false)
        parts = admin_datetime_value_parts(value, default_current_time: default_current_time)
        normalized_time_segments = admin_datetime_time_segments_from_time(parts[:time])

        admin_render_datetime_input(
          mode: "split_datetime",
          parts: parts,
          required: required,
          wrapper_class: wrapper_class,
          target_inputs: [
            {
              type: "hidden",
              name: date_name,
              id: date_id || admin_datetime_dom_id(date_name),
              value: parts[:date_input],
              data: { admin_datetime_target: "date" }
            },
            {
              type: "hidden",
              name: hour_name,
              id: hour_id || admin_datetime_dom_id(hour_name),
              value: normalized_time_segments[:hour],
              data: { admin_datetime_target: "hour" }
            },
            {
              type: "hidden",
              name: minute_name,
              id: minute_id || admin_datetime_dom_id(minute_name),
              value: normalized_time_segments[:minute],
              data: { admin_datetime_target: "minute" }
            }
          ]
        )
      end

      def admin_date_and_time_field_tag(date_name:, time_name:, value: nil, date_id: nil, time_id: nil, required: false, wrapper_class: nil, default_current_time: false)
        parts = admin_datetime_value_parts(value, default_current_time: default_current_time)

        admin_render_datetime_input(
          mode: "date_and_time",
          parts: parts,
          required: required,
          wrapper_class: wrapper_class,
          target_inputs: [
            {
              type: "hidden",
              name: date_name,
              id: date_id || admin_datetime_dom_id(date_name),
              value: parts[:date_input],
              data: { admin_datetime_target: "date" }
            },
            {
              type: "hidden",
              name: time_name,
              id: time_id || admin_datetime_dom_id(time_name),
              value: parts[:time],
              data: { admin_datetime_target: "time" }
            }
          ]
        )
      end

      def admin_time_field_tag(name, value = nil, id: nil, required: false, input_class: nil, wrapper_class: nil, default_current_time: false)
        parts = admin_datetime_value_parts(value, include_date: false, default_current_time: default_current_time)

        admin_render_datetime_input(
          mode: "time_only",
          parts: parts,
          include_date: false,
          required: required,
          wrapper_class: wrapper_class,
          target_inputs: [
            {
              type: "hidden",
              name: name,
              id: id || admin_datetime_dom_id(name),
              value: parts[:time],
              class: input_class,
              data: { admin_datetime_target: "time" }
            }
          ]
        )
      end

      private

      def admin_render_datetime_input(mode:, parts:, target_inputs:, include_date: true, required: false, wrapper_class: nil, calendar_min: nil, calendar_max: nil)
        wrapper_classes = ["admin-datetime-input", "admin-datetime-input--#{mode}"]
        wrapper_classes << wrapper_class if wrapper_class.present?
        validation = admin_datetime_validation_state(
          mode: mode,
          parts: parts,
          include_date: include_date,
          required: required,
          min_date: calendar_min,
          max_date: calendar_max
        )
        wrapper_classes << "admin-datetime-input--invalid" unless validation[:valid]
        describedby_id = "#{admin_datetime_dom_id(target_inputs.first[:id] || target_inputs.first[:name])}_error"
        shared_aria = {
          invalid: (!validation[:valid]).to_s,
          describedby: describedby_id
        }

        content_tag(
          :div,
          class: wrapper_classes.compact.join(" "),
          data: {
            admin_datetime_input: true,
            admin_datetime_mode: mode,
            admin_datetime_required: required,
            admin_datetime_min_date: calendar_min,
            admin_datetime_max_date: calendar_max,
            admin_datetime_valid: validation[:valid]
          }
        ) do
          nodes = target_inputs.map do |input|
            tag.input(**input.compact)
          end

          if include_date
            nodes << tag.input(
              type: "date",
              value: parts[:date_input],
              min: calendar_min,
              max: calendar_max,
              class: "admin-datetime-input__date-input",
              data: { admin_datetime_role: "date-input" },
              autocomplete: "off",
              aria: shared_aria.merge(label: "Date")
            )
          end

          nodes << tag.input(
            type: "text",
            value: admin_datetime_visible_time_value(parts),
            placeholder: "HH:MM",
            maxlength: 5,
            class: "admin-datetime-input__time-input",
            data: { admin_datetime_role: "time-input" },
            inputmode: "numeric",
            autocomplete: "off",
            aria: shared_aria.merge(label: "Time")
          )

          nodes << content_tag(
            :p,
            validation[:message],
            id: describedby_id,
            class: "admin-datetime-input__error",
            data: { admin_datetime_role: "error" },
            aria: { live: "polite" }
          )

          safe_join(nodes)
        end
      end

      def admin_datetime_value_parts(value, include_date: true, default_current_time: false)
        if value.blank? && default_current_time
          default_time = Time.zone.now.change(sec: 0)
          return admin_datetime_value_parts(default_time, include_date: include_date)
        end

        blank_parts = {
          date_input: "",
          date_display: "",
          raw_date: "",
          time: "",
          raw_time: ""
        }
        return blank_parts if value.blank?

        case value
        when Time, DateTime, ActiveSupport::TimeWithZone
          date_input = value.strftime("%Y-%m-%d")
          time = value.strftime("%H:%M")
          return blank_parts.merge(
            date_input: include_date ? date_input : "",
            date_display: include_date ? admin_datetime_display_date(date_input) : "",
            raw_date: include_date ? date_input : "",
            time: time,
            raw_time: time
          )
        when Date
          date_input = value.iso8601
          return blank_parts.merge(
            date_input: include_date ? date_input : "",
            date_display: include_date ? admin_datetime_display_date(date_input) : "",
            raw_date: include_date ? date_input : ""
          )
        end

        raw_value = value.to_s.strip
        return blank_parts if raw_value.blank?

        if !include_date
          time = admin_datetime_normalized_time(raw_value)
          return blank_parts.merge(time: time, raw_time: raw_value)
        end

        raw_date = ""
        raw_time = ""

        if (simple_match = raw_value.match(/\A(?<date>\d{4}[\/-]\d{1,2}[\/-]\d{1,2})(?:[T\s]+(?<time>\d{1,4}|\d{1,2}:\d{0,2}))?\z/))
          raw_date = simple_match[:date].to_s
          raw_time = simple_match[:time].to_s
        else
          parsed_time = Time.zone.parse(raw_value)
          if parsed_time.present?
            date_input = parsed_time.strftime("%Y-%m-%d")
            time = parsed_time.strftime("%H:%M")
            return blank_parts.merge(
              date_input: date_input,
              date_display: admin_datetime_display_date(date_input),
              raw_date: date_input,
              time: time,
              raw_time: time
            )
          end
        end

        date_input = admin_datetime_normalized_date(raw_date)
        time = admin_datetime_normalized_time(raw_time)

        blank_parts.merge(
          date_input: date_input,
          date_display: date_input.present? ? admin_datetime_display_date(date_input) : raw_date,
          raw_date: raw_date,
          time: time,
          raw_time: raw_time
        )
      rescue ArgumentError, TypeError
        blank_parts.merge(raw_date: raw_value)
      end

      def admin_datetime_combined_value(parts)
        return "" unless parts[:date_input].present? && parts[:time].present?

        "#{parts[:date_input]}T#{parts[:time]}"
      end

      def admin_datetime_dom_id(name)
        name.to_s.gsub(/[^a-zA-Z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
      end

      def admin_datetime_date_boundary(value)
        return if value.blank?

        value.to_s.split(/[T\s]/).first.presence
      end

      def admin_datetime_display_date(date_value)
        date_value.to_s.tr("-", "/")
      end

      def admin_datetime_date_segments_from_parts(parts)
        if parts[:date_input].present?
          admin_datetime_date_segments_from_date(parts[:date_input])
        else
          admin_datetime_raw_date_segments(parts[:raw_date])
        end
      end

      def admin_datetime_time_segments_from_parts(parts)
        if parts[:time].present?
          admin_datetime_time_segments_from_time(parts[:time])
        else
          admin_datetime_raw_time_segments(parts[:raw_time])
        end
      end

      def admin_datetime_date_segments_from_date(date_value)
        return { year: "", month: "", day: "" } if date_value.blank?

        year, month, day = date_value.to_s.split("-", 3)
        { year: year.to_s, month: month.to_s, day: day.to_s }
      end

      def admin_datetime_raw_date_segments(raw_date)
        return { year: "", month: "", day: "" } if raw_date.blank?

        match = raw_date.to_s.strip.match(/\A(?<year>\d{1,4})(?:[\/-](?<month>\d{1,2}))?(?:[\/-](?<day>\d{1,2}))?\z/)
        return { year: "", month: "", day: "" } unless match

        {
          year: match[:year].to_s,
          month: match[:month].to_s,
          day: match[:day].to_s
        }
      end

      def admin_datetime_normalized_date(raw_date)
        return "" if raw_date.blank?

        normalized = raw_date.to_s.tr("/", "-")
        return "" unless normalized.match?(/\A\d{4}-\d{1,2}-\d{1,2}\z/)

        Date.strptime(normalized, "%Y-%m-%d").strftime("%Y-%m-%d")
      rescue ArgumentError
        ""
      end

      def admin_datetime_normalized_date_from_segments(segments)
        year = segments[:year].to_s.strip
        month = segments[:month].to_s.strip
        day = segments[:day].to_s.strip
        return "" unless year.match?(/\A\d{4}\z/) && month.match?(/\A\d{1,2}\z/) && day.match?(/\A\d{1,2}\z/)

        Date.new(year.to_i, month.to_i, day.to_i).strftime("%Y-%m-%d")
      rescue ArgumentError
        ""
      end

      def admin_datetime_normalized_time(raw_time)
        return "" if raw_time.blank?

        text = admin_datetime_normalized_time_text(raw_time)

        if (colon_match = text.match(/\A(?<hour>\d{1,2}):(?<minute>\d{1,2})\z/))
          hour = colon_match[:hour].to_i
          minute = colon_match[:minute].to_i
        elsif text.match?(/\A\d{3,4}\z/)
          digits = text.rjust(4, "0")
          hour = digits[0, 2].to_i
          minute = digits[2, 2].to_i
        else
          return ""
        end

        return "" unless hour.between?(0, 23) && minute.between?(0, 59)

        format("%02d:%02d", hour, minute)
      end

      def admin_datetime_normalized_time_from_segments(segments)
        hour = segments[:hour].to_s.strip
        minute = segments[:minute].to_s.strip
        return "" unless hour.match?(/\A\d{1,2}\z/) && minute.match?(/\A\d{1,2}\z/)

        admin_datetime_normalized_time("#{hour}:#{minute.rjust(2, '0')}")
      end

      def admin_datetime_time_segments_from_time(time_value)
        return { hour: "", minute: "" } if time_value.blank?

        hour, minute = time_value.to_s.split(":", 2)
        {
          hour: hour.to_s,
          minute: minute.to_s
        }
      end

      def admin_datetime_raw_time_segments(raw_time)
        return { hour: "", minute: "" } if raw_time.blank?

        text = admin_datetime_normalized_time_text(raw_time)

        if (colon_match = text.match(/\A(?<hour>\d{1,2}):(?<minute>\d{0,2})\z/))
          { hour: colon_match[:hour].to_s, minute: colon_match[:minute].to_s }
        elsif text.match?(/\A\d{1,2}\z/)
          { hour: text, minute: "" }
        elsif text.match?(/\A\d{3,4}\z/)
          digits = text.rjust(4, "0")
          { hour: digits[0, 2], minute: digits[2, 2] }
        else
          { hour: "", minute: "" }
        end
      end

      def admin_datetime_visible_time_value(parts)
        parts[:time].presence || admin_datetime_raw_time_display(parts[:raw_time])
      end

      def admin_datetime_raw_time_display(raw_time)
        return "" if raw_time.blank?

        text = admin_datetime_normalized_time_text(raw_time).gsub(/[^0-9:]/, "")
        return "" if text.blank?

        return text[0, 4] unless text.include?(":")

        hour, minute = text.split(":", 2)
        "#{hour.to_s[0, 2]}:#{minute.to_s[0, 2]}"
      end

      def admin_datetime_normalized_time_text(raw_time)
        raw_time.to_s.strip.gsub(/[[:space:]]+/, "").tr("０１２３４５６７８９：", "0123456789:")
      end

      def admin_datetime_validation_state(mode:, parts:, include_date:, required:, min_date:, max_date:)
        date_segments = include_date ? admin_datetime_date_segments_from_parts(parts) : {}
        time_segments = admin_datetime_time_segments_from_parts(parts)

        date_present = include_date && admin_datetime_segments_present?(date_segments, keys: %i[year month day])
        time_present = admin_datetime_segments_present?(time_segments, keys: %i[hour minute])
        date_complete = !include_date || admin_datetime_segments_complete?(date_segments, keys: %i[year month day])
        time_complete = admin_datetime_segments_complete?(time_segments, keys: %i[hour minute])

        if include_date
          return admin_datetime_invalid_state("日時を入力してください。") if required && !date_present && !time_present
          return admin_datetime_valid_state unless date_present || time_present
          return admin_datetime_invalid_state("日付を正しく入力してください。") if date_present && !date_complete
          return admin_datetime_invalid_state("時刻を正しく入力してください。") if time_present && !time_complete
          return admin_datetime_invalid_state("日付を入力してください。") unless date_present
          return admin_datetime_invalid_state("時刻を入力してください。") unless time_present

          normalized_date = admin_datetime_normalized_date_from_segments(date_segments)
          return admin_datetime_invalid_state("日付を正しく入力してください。") if normalized_date.blank?

          if min_date.present? && normalized_date < min_date
            return admin_datetime_invalid_state("日付は#{admin_datetime_display_date(min_date)}以降で入力してください。")
          end

          if max_date.present? && normalized_date > max_date
            return admin_datetime_invalid_state("日付は#{admin_datetime_display_date(max_date)}以前で入力してください。")
          end
        else
          return admin_datetime_invalid_state("時刻を入力してください。") if required && !time_present
          return admin_datetime_valid_state unless time_present
          return admin_datetime_invalid_state("時刻を正しく入力してください。") unless time_complete
        end

        normalized_time = admin_datetime_normalized_time_from_segments(time_segments)
        return admin_datetime_invalid_state("時刻を正しく入力してください。") if normalized_time.blank?

        admin_datetime_valid_state
      end

      def admin_datetime_valid_state
        { valid: true, message: "" }
      end

      def admin_datetime_invalid_state(message)
        { valid: false, message: message }
      end

      def admin_datetime_segments_present?(segments, keys:)
        keys.any? { |key| segments[key].to_s.strip.present? }
      end

      def admin_datetime_segments_complete?(segments, keys:)
        keys.all? { |key| segments[key].to_s.strip.present? }
      end
    end
  end
end
