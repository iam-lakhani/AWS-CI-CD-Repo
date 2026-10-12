## Architecture

```
Developer → GitHub (source) → AWS (build) → Docker image → Docker Hub (registry) → AWS EC2 (deploy)
                                                                  ↑
                                              MobaXterm (SSH access to EC2)
```

_Add an architecture diagram here: `docs/architecture.png`_

## Tech Stack

| Area | Tools |
|------|-------|
| Language / Framework | Python, Flask |
| Source Control | GitHub |
| CI/CD Build | AWS CodeBuild (`buildspec.yml`) |
| CI/CD Deploy | AWS CodeDeploy (`appspec.yml`, agent on EC2) |
| Server Access | MobaXterm (SSH into EC2) |
| Containerization | Docker |
| Registry | Docker Hub |
| Deployment Target | AWS EC2 (Ubuntu Server) |

## Pipeline Stages

1. **Source** – Code is pushed to the GitHub repository
2. **Build** – AWS CodeBuild runs the steps defined in `buildspec.yml` and builds the Docker image
3. **Push** – The image is pushed to Docker Hub
4. **Deploy** – AWS CodeDeploy reads `appspec.yml` and uses the CodeDeploy agent on the EC2 instance to run the deployment scripts
5. **Run** – `scripts/stop_container.sh` stops the old container, then `scripts/start_container.sh` starts the new one
6. **Verify** – Confirm the app responds on the EC2 public IP

MobaXterm is used to SSH into the EC2 instance for setup (installing Docker and the CodeDeploy agent) and debugging.

## Project Structure

```
.
├── scripts/
│   ├── start_container.sh   # Starts the Docker container on EC2 (CodeDeploy hook)
│   └── stop_container.sh    # Stops/removes the old container (CodeDeploy hook)
├── app.py                   # Flask application entry point
├── appspec.yml              # AWS CodeDeploy deployment instructions
├── buildspec.yml            # AWS CodeBuild build instructions
├── Dockerfile               # Container image definition
├── requirements.txt         # Python dependencies
└── README.md
```

## Getting Started

### Prerequisites

- Python 3.x
- Docker
- Git
- AWS account with an EC2 instance
- MobaXterm (for SSH into EC2)
- Docker Hub account

### Run Locally

```bash
git clone https://github.com/iam-lakhani/<repo>.git
cd <repo>
pip install -r requirements.txt
python app.py
```

### Run with Docker

```bash
docker build -t <dockerhub-username>/<image-name>:latest .
docker run -d -p 5000:5000 <dockerhub-username>/<image-name>:latest
```

App available at `http://localhost:5000`.

## Configuration & Secrets

| Variable | Description |
|----------|-------------|
| `DOCKERHUB_USERNAME` | Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token |

Store these as environment variables in your AWS CodeBuild project, not in the code. Never commit keys, tokens or `.pem` files to the repository.

## Build & Deploy

### Build (AWS CodeBuild)

`buildspec.yml` defines the build phases: log in to Docker Hub, build the image and push it.

### Deploy (AWS CodeDeploy)

`appspec.yml` tells CodeDeploy what to run on the EC2 instance. The lifecycle hooks call the scripts in `scripts/`:

| Script | Purpose |
|--------|---------|
| `stop_container.sh` | Stops and removes the currently running container |
| `start_container.sh` | Pulls the latest image from Docker Hub and starts a new container |

Open `http://<EC2-public-IP>` to verify.

> Make sure the EC2 security group allows inbound traffic on the port you expose (80 or 5000) and SSH (22), and that the instance has an IAM role that lets the CodeDeploy agent work.

### One-time EC2 setup (via MobaXterm)

Connect with the EC2 public IP, user `ubuntu`, and your `.pem` key, then install Docker and the CodeDeploy agent.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Deployment fails in CodeDeploy | Check the CodeDeploy agent status on EC2 and the deployment logs |
| Cannot reach app on EC2 IP | Check security group inbound rules and port mapping |
| MobaXterm SSH connection refused | Verify the `.pem` key, username and port 22 access |
| `docker pull` fails | Confirm the image name/tag and Docker Hub login |
| Container exits immediately | Check logs with `docker logs <container-name>` |

## Challenges & Lessons Learned

### CodeDeploy agent installation failed on Ubuntu 26.04

**Problem:** While setting up the AWS CodeDeploy agent on the EC2 instance through MobaXterm, the agent installation failed. I had launched the instance with **Ubuntu Server 26.04 LTS**, and on this newer OS the Ruby package that got installed was **Ruby 3.3.8**, a version the CodeDeploy agent does not support. Because the agent depends on Ruby, it could not be installed as-is.

**Error seen:** 
sudo ./install auto
I, [2026-10-11T05:46:04.109992 #2456]  INFO -- : Starting Ruby version check.
E, [2026-10-11T05:46:04.111816 #2456] ERROR -- : Current running Ruby version for root is 3.3.8, but Ruby version 2.x, 3.x needs to be installed.
E, [2026-10-11T05:46:04.111841 #2456] ERROR -- : If you already have the proper Ruby version installed, please either create a symlink to /usr/bin/ruby2.x,
E, [2026-10-11T05:46:04.112215 #2456] ERROR -- : or run this install script with right interpreter. Otherwise please install Ruby 2.x, 3.x for root user.
E, [2026-10-11T05:46:04.112234 #2456] ERROR -- : You can get more information by running the script with --help option.

**Workaround:**
cd /home/ubuntu
wget -q https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/releases/codedeploy-agent_1.8.1-26_all.deb -O cdagent.deb
sudo dpkg --ignore-depends=ruby3.2 -i cdagent.deb

**Lesson learned:** The newest OS image is not always the best choice. Agents and their dependencies often lag behind new OS releases. For the next deployment I will launch the EC2 instance with **Ubuntu Server 24.04 LTS or an older supported LTS**, so the default Ruby version is one the CodeDeploy agent supports and it installs without a workaround.

### CodeDeploy agent stopped working after changing IAM role policies

**Problem:** After I changed the IAM role policies attached to the EC2 instance, the CodeDeploy agent stopped working and deployments no longer ran.

**Fix:** Restart the agent on the EC2 instance (via MobaXterm) so it picks up the updated permissions:

```bash
sudo service codedeploy-agent restart
sudo service codedeploy-agent status
```

**Lesson learned:** Whenever IAM role policies change, restart the CodeDeploy agent and confirm its status before triggering a new deployment.


> Tip: Before picking an AMI, check the AWS CodeDeploy agent documentation for the supported operating system versions.

## Contributing

1. Fork the repo
2. Create a branch: `git checkout -b feature/your-feature`
3. Commit and push your changes
4. Open a Pull Request

## License

Distributed under the MIT License. See `LICENSE` for details.

## Contact

**Tarun Lakhani** – [GitHub: iam-lakhani](https://github.com/iam-lakhani)
