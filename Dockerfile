ARG PARENT_IMAGE=:
    FROM $PARENT_IMAGE
    ARG PYTORCH_DEPS=cpuonly
    ARG PYTHON_VERSION=3.12
    ARG MAMBA_DOCKERFILE_ACTIVATE=1  # (otherwise python will not be found)
    
    # Install micromamba env and dependencies
    RUN micromamba install -n base -y python=$PYTHON_VERSION \
        pytorch $PYTORCH_DEPS -c conda-forge -c pytorch -c nvidia && \
        micromamba clean --all --yes
    
    ENV CODE_DIR=/home/$MAMBA_USER
    
    # Copy setup file only to install dependencies
    COPY --chown=$MAMBA_USER:$MAMBA_USER ./setup.py ${CODE_DIR}/stable-baselines3/setup.py
    COPY --chown=$MAMBA_USER:$MAMBA_USER ./stable_baselines3/version.txt ${CODE_DIR}/stable-baselines3/stable_baselines3/version.txt
    
    RUN cd ${CODE_DIR}/stable-baselines3 && \
        # pip install uv && \
        pip install -e .[extra,tests,docs] && \
        # Use headless version for docker
        # pip uninstall opencv-python && \
        pip install opencv-python-headless && \
        pip install imitation && \
        pip cache purge 
        # uv cache clean
    
    # Install ROS2
    USER root
    # RUN apt-get update && apt-get install -y sudo 
    
    # setup timezone
    RUN echo 'Etc/UTC' > /etc/timezone && \
        ln -s /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
        apt-get update && \
        apt-get install -q -y --no-install-recommends tzdata && \
        rm -rf /var/lib/apt/lists/*
    
    # install packages
    RUN apt-get update && apt-get install -q -y --no-install-recommends \
        dirmngr \
        gnupg2 \
        && rm -rf /var/lib/apt/lists/*
    
    # setup keys
    RUN set -eux; \
           key='C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654'; \
           export GNUPGHOME="$(mktemp -d)"; \
           gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key"; \
           mkdir -p /usr/share/keyrings; \
           gpg --batch --export "$key" > /usr/share/keyrings/ros2-latest-archive-keyring.gpg; \
           gpgconf --kill all; \
           rm -rf "$GNUPGHOME"
    
    # setup sources.list
    RUN echo "deb [ signed-by=/usr/share/keyrings/ros2-latest-archive-keyring.gpg ] http://packages.ros.org/ros2/ubuntu jammy main" > /etc/apt/sources.list.d/ros2-latest.list
    
    # setup environment
    ENV LANG=C.UTF-8
    ENV LC_ALL=C.UTF-8
    
    ENV ROS_DISTRO=humble
    
    # install ros2 packages
    RUN apt-get update && apt-get install -y --no-install-recommends \
        ros-humble-ros-core=0.10.0-1* \
        && rm -rf /var/lib/apt/lists/*
    
    # install bootstrap tools
    RUN apt-get update && apt-get install --no-install-recommends -y \
        build-essential \
        git \
        python3-colcon-common-extensions \
        python3-colcon-mixin \
        python3-rosdep \
        python3-vcstool \
        && rm -rf /var/lib/apt/lists/*

    # bootstrap rosdep
    RUN rosdep init && \
    rosdep update --rosdistro $ROS_DISTRO

    # setup colcon mixin and metadata
    RUN colcon mixin add default \
        https://raw.githubusercontent.com/colcon/colcon-mixin-repository/master/index.yaml && \
        colcon mixin update && \
        colcon metadata add default \
        https://raw.githubusercontent.com/colcon/colcon-metadata-repository/master/index.yaml && \
        colcon metadata update

    # install ros2 packages
    RUN apt-get update && apt-get install -y --no-install-recommends \
        ros-humble-ros-base=0.10.0-1* \
        && rm -rf /var/lib/apt/lists/*

    # install ros2 packages
    RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-perception=0.10.0-1* \
    && rm -rf /var/lib/apt/lists/*

    # setup entrypoint
    COPY ./ros_entrypoint.sh /home/mamba/ros_entrypoint.sh
        
    RUN chmod +x /home/mamba/ros_entrypoint.sh
        
    USER $MAMBA_USER
    ENTRYPOINT [ "/home/mamba/ros_entrypoint.sh" ]
    CMD ["bash"]