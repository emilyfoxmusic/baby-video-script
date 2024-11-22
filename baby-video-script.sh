#!/bin/bash

## -------------------- params -------------------- ##

baby_name="Baby Name Here" # Add your baby's name here
baby_birthday="2000-01-01" # Put their birthday here (YYYY-MM-DD format)

## ------------------------------------------------ ##

# Generate a unique name for the intermediate folder based on the current date and time
timestamp=$(date +%Y%m%d-%H%M%S)
processed_folder="processed_$timestamp"
filelist="filelist_$timestamp.txt"

# Create the timestamped 'Processed' directory
mkdir "$processed_folder"

# Function to calculate the baby's exact age in months and days using `date`
calculate_age() {
  local video_date="$1"

  # Calculate the difference between the current date and the birthday
  local birth_year=$(date -d "$baby_birthday" '+%Y')
  local birth_month=$(date -d "$baby_birthday" '+%-m')
  local birth_day=$(date -d "$baby_birthday" '+%-d')

  local video_year=$(date -d "$video_date" '+%Y')
  local video_month=$(date -d "$video_date" '+%-m')
  local video_day=$(date -d "$video_date" '+%-d')

  # Calculate years, months, and days
  local age_years=$((video_year - birth_year))
  local age_months=$((video_month - birth_month))
  local age_days=$((video_day - birth_day))

  # Adjust if the birthday hasn't occurred yet this year
  if [ $age_months -lt 0 ]; then
      age_months=$((age_months + 12))
      age_years=$((age_years - 1))
  fi

  # Adjust if the day hasn't occurred yet this month
  if [ $age_days -lt 0 ]; then
      # Subtract one from age_months and calculate the days in the previous month
      age_months=$((age_months - 1))
      
      if [[ $video_month -eq 1 || $video_month -eq 2 || $video_month -eq 4 || $video_month -eq 6 || $video_month -eq 8 || $video_month -eq 9 || $video_month -eq 11 ]]; then
        age_days=$((age_days + 31))
      elif [[ $video_month -eq 5 || $video_month -eq 7 || $video_month -eq 10 || $video_month -eq 12 ]]; then
        age_days=$((age_days + 30))
      else
          # For the dates we care about, this approximation of the leap year works
          if [[ $((video_year % 4)) -eq 0 ]]; then
              age_days=$((age_days + 29))
          else
              age_days=$((age_days + 28))
          fi
      fi
  fi

  if [ $age_years -eq 0 ]; then
    if [ $age_months -eq 0 ]; then
      echo "$age_days days"
    else
      echo "$age_months months, $age_days days"
    fi
  else
    echo "$age_years years, $age_months months, $age_days days"
  fi
}

# Iterate through all MP4 files in the current directory
for video_file in *.mp4; do
  # Skip if no MP4 files are found
  [ -f "$video_file" ] || continue
  
  echo "Processing $video_file..."
  
  # Try to get the creation time from the metadata using ffprobe
  creation_time=$(ffprobe -v quiet -print_format json -show_format "$video_file" | jq -r '.format.tags.creation_time')
  
  # Check if creation_time was found; if not, extract the date from the filename
  if [ "$creation_time" != "null" ] && [ -n "$creation_time" ]; then
    # Convert creation time to epoch time
    video_date="$creation_time"

    # Calculate the baby's exact age at the time of the video (from metadata)
    age=$(calculate_age "$video_date")

    filename=$(echo "$video_date" | sed 's/[T:]/-/g' | sed 's/\..*Z$//')

    # Apply ffmpeg command to add the creation time as overlay text (countdown), resize to portrait Full HD
    epoch_time=$(date -d "$creation_time" +%s)
    ffmpeg -i "$video_file" -vf "
        scale=1080:1920:force_original_aspect_ratio=decrease,
        pad=1080:1920:-1:-1:color=black,
        drawtext=fontfile=/usr/share/fonts/TTF/TSCu_Comic.ttf:text='%{pts\:localtime\:$epoch_time}':x=W-text_w-10:y=H-text_h-10:fontsize=28:fontcolor=white:shadowcolor=black:shadowx=2:shadowy=2:box=1:boxcolor=0x00000080:boxborderw=5,
        drawtext=fontfile=/usr/share/fonts/TTF/TSCu_Comic.ttf:text='$baby_name - $age old':x=10:y=H-text_h-10:fontsize=28:fontcolor=white:shadowcolor=black:shadowx=2:shadowy=2:box=1:boxcolor=0x00000080:boxborderw=5
    " -c:a copy "$processed_folder/${filename}.mp4"

  else
    # If no creation time found, extract the date from the filename (assumed format "VID-YYYYMMDD-")
    video_date=$(echo "$video_file" | grep -oP '\d{8}' | head -n 1)

    age=$(calculate_age "$video_date")

    # Reformat the date from YYYYMMDD to YYYY-MM-DD using date
    formatted_date=$(date -d "${video_date}" +%Y-%m-%d)
    video_date="$formatted_date"  # Use the formatted date from filename as the video date

    # Filename needs to be unique but we don't have the time, so append a random string (we can't order it anyway)
    filename=$video_date-$(openssl rand -hex 6)

    # Apply ffmpeg command to add the formatted date as overlay text (no countdown), resize to portrait Full HD
    ffmpeg -i "$video_file" -vf "
        scale=1080:1920:force_original_aspect_ratio=decrease,
        pad=1080:1920:-1:-1:color=black,
        drawtext=fontfile=/usr/share/fonts/TTF/TSCu_Comic.ttf:text='$formatted_date':x=W-text_w-10:y=H-text_h-10:fontsize=28:fontcolor=white:shadowcolor=black:shadowx=2:shadowy=2:box=1:boxcolor=0x00000080:boxborderw=5,
        drawtext=fontfile=/usr/share/fonts/TTF/TSCu_Comic.ttf:text='$baby_name - $age old':x=10:y=H-text_h-10:fontsize=28:fontcolor=white:shadowcolor=black:shadowx=2:shadowy=2:box=1:boxcolor=0x00000080:boxborderw=5
    " -c:a copy "$processed_folder/${filename}.mp4"
  fi

  echo "Finished processing $video_file"
done

echo "All videos processed and saved in the '$processed_folder' folder."

# Sort the files lexicographically and add them to the filelist
for f in $(ls "$processed_folder"/*.mp4 | sort); do
  echo "file '$f'" >> $filelist
done

# Concatenate the videos using ffmpeg
ffmpeg -f concat -safe 0 -i $filelist -c copy output_$timestamp.mp4

echo "Video created! Filename is output_$timestamp.mp4."
