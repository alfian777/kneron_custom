# TODO
# 1. PATH Issue, dont know why need to addess the full bin location to run build. (EX : /workspace/miniconda/bin/python autogen.py instead of python autogen.py)

# Put Latest flag so that it will behave like git rebase 
FROM kneron/toolchain:latest

# Define Global Variable
ARG PUB_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDKFPEhrfhN4KVlwiMpu0td8FpYRilFhqTf2mN+OSZOkRv+NYYBfI8dlZDGNqVQvLC8Id0a7huuKmXMUfVctwwHmo8HxhNmIZWsgPG0qCoWdus56bYOSHm5XSkg4dEJOAVOc3evijMMZC/imTdRY0qsfj5J1CHmU4I4/ZzW8eIzWahCbu4GPAlSwFTyoxQxCNnvcFiJfWhLYfJj5pm4gdTyLB3i3BHe3EasYPsSxxPRuv4GJGet+B46qFcRYXx9xr7bmOEEh7v1Z2EBZolrvklTpyYP6G10ZpFhxDAsJFgnc1PqzeDMZLhilzkK5fVE091HbRooglav09LPtRdii8/J root"
ARG VSCODE_COMMIT_SHA="ccbaa2d27e38e5afa3e5c21c1c7bef4657064247"
ARG VSCODE_ARCHIVE="vscode-server-linux-x64.tar.gz"
ARG VSCODE_OWNER='microsoft'
ARG VSCODE_REPO='vscode'

# Update Package & Install 
RUN apt-get update -y
RUN apt-get install -y nano openssh-server 

# Path Hack.. 
RUN export PATH="/workspace/miniconda/bin:/workspace/miniconda/condabin:/workspace/cmake/bin:$PATH"

# Root SSH Setup
RUN echo "root:root" | chpasswd
RUN echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
RUN cat /etc/ssh/sshd_config
RUN mkdir /root/.ssh
RUN chown -R root:root /root/.ssh;chmod -R 700 /root/.ssh
RUN echo  "StrictHostKeyChecking=no" >> /etc/ssh/ssh_config

# Install VSCODE SERVER : https://gist.github.com/b01/0a16b6645ab7921b0910603dfb85e4fb
RUN curl -L "https://update.code.visualstudio.com/commit:${VSCODE_COMMIT_SHA}/server-linux-x64/stable" -o "/tmp/${VSCODE_ARCHIVE}"
#RUN curl -L "https://update.code.visualstudio.com/latest/server-linux-x64/stable" -o "/tmp/${VSCODE_ARCHIVE}"
# Make the parent directory where the server should live.
# NOTE: Ensure VS Code will have read/write access; namely the user running VScode or container user.
RUN mkdir -vp ~/.vscode-server/bin/"${VSCODE_COMMIT_SHA}"
# Extract the tarball to the right location.
RUN tar --no-same-owner -xzv --strip-components=1 -C ~/.vscode-server/bin/"${VSCODE_COMMIT_SHA}" -f "/tmp/${VSCODE_ARCHIVE}"

# Install Public Key 
RUN echo ${PUB_KEY} >> /root/.ssh/authorized_keys

# Setup Keras Docs on port 8000
# RUN pip install mkdocs
# RUN /bin/bash -c "pip install mkdocs"
RUN /workspace/miniconda/bin/pip install mkdocs notebook
RUN mkdir /workspace/docs/;\
   wget -P /workspace/docs/ "https://github.com/keras-team/keras/archive/refs/tags/2.2.4.zip";\
   mkdir /workspace/projects;\
   unzip /workspace/docs/2.2.4.zip -d /workspace/docs/;\
   rm /workspace/docs/2.2.4.zip;\
   cd /workspace/docs/keras-2.2.4/docs/;\
   /workspace/miniconda/bin/python autogen.py

# Enable SSH to obtain environment variable from /etc/environment. 
# By default env is cleared by sshd whenever loged in, so need to obtain from /etc/environment
# then purge /etc/environment & replace with current env
RUN echo "PermitUserEnvironment yes" >> /etc/ssh/sshd_config; \ 
   rm /etc/environment; \
   env >> /etc/environment

# Restart sshd, Run Jupiter notebook without password, run mkdocs for keras 2.2.4
ENTRYPOINT service ssh restart & \
   /workspace/miniconda/bin/jupyter notebook --no-browser --ip="0.0.0.0" --NotebookApp.token='' --NotebookApp.password='' --allow-root & \
   cd /workspace/docs/keras-2.2.4/docs/ ; /workspace/miniconda/bin/mkdocs serve

# Default command so that it will not close
CMD /bin/bash