#!/bin/bash

################################################
# Baby's details
################################################

baby_name="Baby Name Here" # Add your baby's name here
baby_birthday="2000-01-01" # Put their birthday here (YYYY-MM-DD format)

################################################

# Folders and filenames
timestamp=$(date +%Y%m%d-%H%M%S)
processed_folder="processed_$timestamp"
filelist="filelist_$timestamp.txt"

mkdir "$processed_folder"

################################################
## Calculating the age
################################################
print_days() {
    local age_days="$1"
    if [ $age_days -eq 1 ]; then
        echo "$age_days day"
    else
        echo "$age_days days"
    fi
}

print_months() {
    local age_months="$1"

    if [ $age_months -eq 1 ]; then
        echo "$age_months month"
    else
        echo "$age_months months"
    fi
}

print_years() {
    local age_years="$1"

    if [ $age_years -eq 1 ]; then
        echo "$age_years year"
    else
        echo "$age_years years"
    fi
}

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

    # Final adjustment for boundary to avoid 1 year, -1 months
  if [ $age_months -lt 0 ]; then
      age_months=$((age_months + 12))
      age_years=$((age_years - 1))
  fi

  if [ $age_years -eq 0 ]; then
    if [ $age_months -eq 0 ]; then
        echo "$(print_days $age_days)"
    else
      echo "$(print_months $age_months), $(print_days $age_days)"
    fi
  else
    echo "$(print_years $age_years), $(print_months $age_months), $(print_days $age_days)"
  fi
}

################################################

all_video_files=(*.mp4)
file_count=${#all_video_files[@]}

if [ $file_count -eq 0 ]; then
    exit 1
fi

# Define color codes
ORANGE='\033[38;5;214m'   # A shade of orange
RESET='\033[0m'           # Reset to default color

################################################
## Process all video files - same format with overlay text
################################################

for i in "${!all_video_files[@]}"; do
    video_file=${all_video_files[$i]}

    echo -e "Processing ${ORANGE}file $((i + 1)) of $file_count${RESET}: $video_file"
    
    # Try to get the creation time from the metadata using ffprobe
    creation_time=$(ffprobe -v quiet -print_format json -show_format "$video_file" | jq -r '.format.tags.creation_time')
    
    # Check if creation_time was found; if not, extract the date from the filename
    if [ "$creation_time" != "null" ] && [ -n "$creation_time" ]; then
        video_date=$(date -d "$creation_time" "+%Y-%m-%d %H:%M")
    else
        # If no creation time found, extract the date from the filename (assumed format "VID-YYYYMMDD-")
        video_date=$(echo "$video_file" | grep -oP '\d{8}' | head -n 1)
        # Reformat the date from YYYYMMDD to YYYY-MM-DD using date
        video_date=$(date -d "${video_date}" +%Y-%m-%d)
    fi

    age=$(calculate_age "$video_date")
    echo "Video date is $video_date, baby was $age old"

    # Filename needs to be unique even if we don't have the time, so append a random string (we can't order ones without times anyway)
    filename=$(echo "$video_date" | sed 's/[ :]/-/g')-$(openssl rand -hex 3)

    # Re-encode to landscape, full HD in preparation for concatenation
    ffmpeg -loglevel warning -i "$video_file" -vf "
        scale=1920:1080:force_original_aspect_ratio=decrease,
        pad=1920:1080:-1:-1:color=black,
        drawtext=fontfile=/usr/share/fonts/TTF/TSCu_Comic.ttf:text='$(echo "$video_date" | sed 's/:/\\:/g')':x=W-text_w-10:y=H-text_h-10:fontsize=48:fontcolor=white:shadowcolor=black:shadowx=2:shadowy=2:box=1:boxcolor=0x00000080:boxborderw=5,
        drawtext=fontfile=/usr/share/fonts/TTF/TSCu_Comic.ttf:text='$baby_name - $age old':x=10:y=H-text_h-10:fontsize=48:fontcolor=white:shadowcolor=black:shadowx=2:shadowy=2:box=1:boxcolor=0x00000080:boxborderw=5
    " -c:v libx264 -c:a aac -b:v 5000k -b:a 190k -s 1920x1080 -r 30 "$processed_folder/${filename}.mp4"

  echo "Finished processing $video_file"
done

echo "All videos processed and saved in the '$processed_folder' folder"

################################################
## Concatenate videos
################################################

# Sort the files lexicographically (due to filenames this is also chronological, which is the aim)
for f in $(ls "$processed_folder"/*.mp4 | sort); do
  echo "file '$f'" >> $filelist
done

ffmpeg -loglevel warning -f concat -safe 0 -i $filelist -c copy "$processed_folder/final_$timestamp.mp4"

echo "Video created! File can be found at $processed_folder/final_$timestamp.mp4"
