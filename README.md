# Baby Video Script (A Hacky Script Wot I Wrote)

This script is for creating one long video out of (many) baby videos. It does the following:

1. converts all videos (.mp4s only) to portrait full HD (adding black bars to landscape videos)
2. adds a timestamp (and clock/counter where metadata is available) to the video
3. adds the baby's age in the bottom left
4. concatenates all the videos, chronologically.

The script should be placed into the directory where the original videos live. It will process intermediate videos into a new folder, and then output the new concatenated video in the main folder as `output_{timestamp}.mp4`. (If you run it multiple times without deleting the outputs you will get strange results...)

I do not pretend that the code is nice. I also have only used it for my specific videos and use case. But it works for me for now, and if you find it useful in some way then all the better :)