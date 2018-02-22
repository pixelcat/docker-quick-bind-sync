#!/bin/sh
set -e

APP_VOLUME=${APP_VOLUME:-/volume}
HOST_VOLUME=${HOST_VOLUME:-/host}
OWNER_UID=${OWNER_UID:-0}
GROUP_ID=${GROUP_ID:-0}

# Allow setting maximum iNotify
if [ ! -z ${MAXIMUM_INOTIFY_WATCHES} ]; then
  echo fs.inotify.max_user_watches=${MAXIMUM_INOTIFY_WATCHES} | tee -a /etc/sysctl.conf && sysctl -p
fi

# if the user did not set anything particular to use, we use root
# since this means, no special user has been created on the target container
# thus it is most probably root to run the daemon and thats a good default then
if [ -z ${OWNER_UID} ];then
   OWNER_UID=0
fi

if [ ! -z ${GROUP_ID} ]; then
  # If gid doesn't exist on the system
  if ! cut -d: -f3 /etc/group | grep -q $GROUP_ID; then
     echo "no group has gid $GROUP_ID"
     groupadd -g ${GROUP_ID} dockersync
  fi
else
  GROUP_ID=0
fi

# if the user with the uid does not exist, create it, otherwise reuse it
if ! cut -d: -f3 /etc/passwd | grep -q ${OWNER_UID}; then
  echo "Creating user with uid ${OWNER_UID}"

  # If user doesn't exist on the system
  useradd -u ${OWNER_UID} -g ${GROUP_ID} dockersync -m
else
  if [ ${OWNER_UID} == 0 ]; then
    # in case it is root, we need a special treatment
    echo "user with uid ${OWNER_UID} already exist and its root"
  else
    # we actually rename the user to unison, since we do not care about
    # the username on the sync container, it will be matched to whatever the target container uses for this uid
    # on the target container anyway, no matter how our user is name here
    echo "User with uid ${OWNER_UID} already exists"
    existing_user_with_uid=$(awk -F: "/:$OWNER_UID:/{print \$1}" /etc/passwd)
    OWNER=`getent passwd "${OWNER_UID}" | cut -d: -f1`
    GROUP=`getent group "${GROUP_ID}" | cut -d: -f1`
    mkdir -p /home/${OWNER}
    usermod -u ${OWNER_UID} -g ${GROUP_ID} ${OWNER}
    usermod --home /home/${OWNER} ${OWNER}
    chown -R ${OWNER} /home/${OWNER}
    chgrp -R ${GROUP} /home/${OWNER}
   fi
fi

export OWNER_HOMEDIR=`getent passwd $OWNER_UID | cut -f6 -d:`
# OWNER should actually be dockersync in all cases the user did not match a system user
export OWNER=`getent passwd "${OWNER_UID}" | cut -d: -f1`
export GROUP=`getent group "${GROUP_ID}" | cut -d: -f1`
chown -R ${OWNER} ${APP_VOLUME}
chgrp -R ${GROUP} ${APP_VOLUME}

if [ ! -f /tmp/initial_sync_finished ]; then
	echo "doing initial sync with unison"
	# we use ruby due to http://mywiki.wooledge.org/BashFAQ/050
	time ruby -e '`unison #{ENV["UNISON_ARGS"]} #{ENV["UNISON_PREFER"]} #{ENV["UNISON_EXCLUDES"]} -numericids -auto -batch /host /volume`'
	#time cp -au  $HOST_VOLUME/.  $APP_VOLUME
	echo "chown ing file to uid ${OWNER_UID}"
	chown -R ${OWNER_UID} ${APP_VOLUME}
	touch /tmp/initial_sync_finished
	echo "initial sync done using unison" >> /tmp/unison.log
else
	echo "skipping initial copy with unison"
fi

# If the first argument passed in looks like a flag
if [ "$(printf %c "$1")" = '-' ]; then
  set -- /sbin/tini -- unison /host /volume "$@"
# If the first argument passed in is unison
elif [ "$1" = 'unison' ]; then
  set -- /sbin/tini -- "$@"
fi

exec "$@"
