Docker Image
===

Local testing
---

    docker build -t lsstsqre/gitlfs-server \
      --build-arg REPO=https://github.com/jhoblitt/git-lfs-s3-server \
      --build-arg REF=tickets/DM-13186-ruby-2.4 \
      .

    docker run -ti -p 8080:80 \
      -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
      -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
      -e AWS_REGION=us-east-1 \
      -e S3_BUCKET=lsst-sqre-prod-git-lfs-us-east-1 \
      -e LFS_SERVER_URL=https://git-lfs.lsst.codes \
      lsstsqre/gitlfs-server

    GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/lsst/afwdata
    cd afwdata/
    sed -i 's|https://git-lfs.lsst.codes|http://localhost:8080|' .lfsconfig
    git lfs pull
