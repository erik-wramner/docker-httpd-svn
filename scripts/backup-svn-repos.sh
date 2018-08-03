#!/bin/bash
#
# Backup Subversion repositories. The script performs full dumps, no hot backups or
# incremental backups. It keeps the most recent backups for each repository and only
# performs a dump if there has been a new checkin since the last time.
#
# Usage: backup-svn-repos.sh svn-base-dir backup-dir backups-to-keep
#
set -e

REPO_BASE_DIR=${1:-/svn/repos}
BACKUP_DIR=${2:-/svn/backup}
BACKUPS_TO_KEEP=${3:-4}
CURRENT_DATE=`date +"%Y%m%d"`

for repo in ${REPO_BASE_DIR}/*; do
  repo_name=`basename $repo`
  repo_revision=`svnlook youngest $repo`

  if stat -t ${BACKUP_DIR}/${repo_name}/${repo_name}-*-${repo_revision}.txt.bz2 >/dev/null 2>&1; then
    echo Skipping backup of ${repo_name}, revision ${repo_revision} already backed up
  else
    echo Backing up ${repo_name} with revision ${repo_revision}...
    mkdir -p ${BACKUP_DIR}/${repo_name}
    base_name=${BACKUP_DIR}/${repo_name}/${repo_name}-${CURRENT_DATE}-${repo_revision}
    svnadmin dump --deltas --quiet "$repo" | \
      bzip2 > ${base_name}.tmp
    mv ${base_name}.tmp ${base_name}.txt.bz2
  fi

  find ${BACKUP_DIR}/${repo_name} -name ${repo_name}-\*.txt.bz2 \
    | sort | head -n -${BACKUPS_TO_KEEP} \
    | xargs --no-run-if-empty rm -f
done
