lock_repo() {
   echo "HELLO"
   echo "lock $1 $2"
   wlc --key $2 --url https://hosted.weblate.org/api/ commit jasp/$1
   wlc --key $2 --url https://hosted.weblate.org/api/ push jasp/$1
   wlc --key $2 --url https://hosted.weblate.org/api/ lock jasp/$1
}

if [ "$QML_REPO" ]
then
  lock_repo $QML_REPO $WEBLATE_KEY
fi

if [ "$R_REPO" ]
then
  lock_repo $R_REPO $WEBLATE_KEY
fi
