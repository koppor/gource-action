#!/bin/bash

# Switch to working directory
cd /gource

# Start Xvfb
printf "> Starting Xvfb "
Xvfb :99 -ac -screen 0 $XVFB_WHD -nolisten tcp &> ./logs/xvfb.log &
xvfb_pid="$!"

# possible race condition waiting for Xvfb.
sleep 5

# Check if git repo exist, else download it from GIT_URL
printf "\n>\n> Repository check \n"
if [ -z "$(ls -A ./git_repos)" ]; then
  printf "> \tUsing single repo \n"

	# Check if git repo needs to be cloned
  if [ -z "$(ls -A ./git_repo)" ]; then
    # Check if GIT_URL is a local folder
    if [[ ${INPUT_GIT_URL:0:2} == "./" ]]; then
      printf "> \tUsing local repository: $(sed "s/.\//\/github\/workspace\/&/g" <<< ${INPUT_GIT_URL})"
      # The action working directory im ounted as /github/workspace
      cp -rf $(sed "s/.\//\/github\/workspace\/&/g" <<< ${INPUT_GIT_URL}) ./git_repo
    else
      # Check if git repo need token
      if [ "${INPUT_GIT_TOKEN}" == "" ]; then
        printf "> \tCloning from public: ${INPUT_GIT_URL}"
        timeout 25s git clone ${INPUT_GIT_URL} ./git_repo >/dev/null 2>&1
      else
        printf "> \tCloning from private: ${INPUT_GIT_URL}"
        # Add git token to access private repository
        timeout 25s git clone $(sed "s/git/${GIT_TOKEN}\@&/g" <<< ${INPUT_GIT_URL}) ./git_repo >/dev/null 2>&1
      fi
    fi
  fi


  if [ -z "$(ls -A ./git_repo)" ]; then
    # // TODO: Add multi repo support
    printf "\n\nERROR: No Git repository found"
    exit 2
  fi

	printf "\n> \tUsing volume mounted git repo"
	gource --output-custom-log ./development.log ./git_repo >/dev/null 2>&1
else
  # // TODO: Add multi repo support
	printf "\n\nERROR: Currently multiple repos are not supported"
  exit 1
fi


# Set proper env variables if we have a logo.
printf "\n>\n> Logo check"
if [ "${INPUT_LOGO_URL}" != "" ]; then
  # // TODO: Add support for local logo
  printf "\n> \tDownloading logo"
	wget -O ./logo.image ${INPUT_LOGO_URL} >/dev/null 2>&1
  convert -geometry x160 ./logo.image ./logo.image

  printf "\n> \tUsing logo from: ${INPUT_LOGO_URL} \n"
  export LOGO=" -i ./logo.image "
  export LOGO_FILTER_GRAPH=";[with_date][2:v]overlay=main_w-overlay_w-40:main_h-overlay_h-40[with_logo]"
  export FILTER_GRAPH_MAP=" -map [with_logo] "
else
  printf "\n> \tNo logo provided, skipping logo setup\n"
  export FILTER_GRAPH_MAP=" -map [with_date] "
fi

# Copy user imgages if provided
printf "\n>\n> Avatars check"
if [ "${INPUT_AVATARS_URL}" != "" ]; then
  printf "\n> \tCopy avatars directory: ${INPUT_AVATARS_URL}\n"
  find "/github/workspace/${INPUT_AVATARS_URL}" -type f -exec cp {} /gource/avatars \;
else
  printf "\n> \tNo avatars directory provided, skipping avatars setup\n"
fi

# Run the visualization
printf "\n>\n> Starting gource script\n"
/usr/local/bin/gource.sh
printf "\n> Gource script completed"

# Copy logs and output file to mounted directory
printf "\n>\n> Clean up"
printf "\n> \tCreate output directory /github/workspace/gource"
mkdir -p /github/workspace/gource/logs
printf "\n> \tCopy generated mp4 to /github/workspace/gource"
cp ./output/gource.mp4 /github/workspace/gource
printf "\n> \tCopy logs to /github/workspace/gource/logs"
cp ./logs/* /github/workspace/gource/logs
printf "\n> \tDelete working directory"
rm -r /gource

# If gource.mp4 dont exist exit with error
if [ ! -f /github/workspace/gource/gource.mp4 ]; then
  printf "\n>\n> ERROR: Can't find: /github/workspace/gource/gource.mp4\n>"
  exit 2
fi

# Exit
printf "\n>\n> Done.\n>"
exit 0
