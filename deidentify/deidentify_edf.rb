# deidentify_edf.rb
# => author: @informaton Hyatt Moore
#
# Modified from :
# => tutorial_03.rb
# => sleepdata.org
# => author: @remomueller
#
# Required Gems:
#
# gem install colorize edfize nsrr --no-document
#
# To Run Script:
#
# ruby deidentify_edf.rb

require 'rubygems'
require 'colorize'
require 'edfize'

# This will randomize the start date by +/- 5 days for of all EDFs in the
# current directory and subdirectories

puts "EDFs available: #{Edfize.edf_paths.count}"

INVALID_DATE = '00.00.00'
CLIPPING_DATE = '01.01.85'
# Date format is "dd.mm.yy"

Edfize.edfs do |edf|

  unless edf.local_patient_identification.to_s.strip.empty?
      puts("local_patient_identification is not empty");
  end

  new_recording_id = "";

  new_patient_id = ""
  original_start_date = Date.strptime(edf.start_date_of_recording,"%d.%m.%y");
  randomized_start_date = original_start_date + rand(11)-5;

# Jiggle date by +/- 5 days
  new_start_date = randomized_start_date.strftime("%d.%m.%y");

# Set date to start of a certain year
# new_start_date = "01.01.16"

  if edf.start_date_of_recording == INVALID_DATE
    initial_date = edf.start_date_of_recording

    edf.update(start_date_of_recording: CLIPPING_DATE)
    puts initial_date.colorize(:red) + " to " + edf.start_date_of_recording.colorize(:green) + " for #{edf.filename}"
  end

  edf.update(start_date_of_recording: new_start_date)
  edf.update(local_patient_identification: new_patient_id)
  edf.update(local_recording_identification: new_recording_id)

  puts "   OK".colorize(:green) + "       #{original_start_date.strftime("%d.%m.%y")}  --> #{new_start_date} for #{edf.filename}"

  puts("\t\tlocal_patient_identification:\t#{edf.local_patient_identification}")
  puts("\t\tlocal_recording_identification:\t#{edf.local_recording_identification}")

end

puts "\nFinished! ".colorize(:green).on_white
