## Session 14 
Execution Verification

The following screenshot shows the Kubernetes Pods created and tested during this session. Most troubleshooting exercises are currently running successfully, while `dns-test` is intentionally showing `ImagePullBackOff` as part of the troubleshooting exercise.

![Session 14 Pods Verification](./images/AllPods.png)

---
This session focuses on using `kubectl` to inspect Kubernetes resources, understand Pod lifecycle information, inspect logs and events, execute commands inside Pods, and troubleshoot common workload problems.

## Session Structure

```text
01-kubectl-get
02-kubectl-describe
03-kubectl-logs
04-kubectl-exec
05-events
06-crashloopbackoff
07-imagepullbackoff
08-pending-pods
09-service-dns-troubleshooting
mini-project
```

---

# 1. `kubectl get`

`kubectl get` is used to view Kubernetes resources and their current state.

### Commands used

```bash
kubectl get pods
```

Shows Pods in the current namespace.

```bash
kubectl get pods -w
```

Watches Pod status changes continuously.

The `-w` / `--watch` option keeps the command running and updates the output when the resource changes.

### General syntax

```bash
kubectl get <resource-type>
kubectl get <resource-type> <resource-name>
```

Examples:

```bash
kubectl get pods
kubectl get pod get-demo
kubectl get pods -o wide
```

### Screenshot

![kubectl get](./images/kubectl-get.png)

---

# 2. `kubectl describe`

`kubectl describe` provides detailed information about a Kubernetes resource.

### Command

```bash
kubectl describe pod get-demo
```

The general syntax is:

```text
kubectl describe <resource-type> <resource-name>
```

Here:

- `pod` = resource type
- `get-demo` = resource name

The resource/name form also works:

```bash
kubectl describe pod/get-demo
```

The `/` is optional when using the separate resource and name form.

### What `describe` is useful for

`describe` gives information that is not normally shown by `kubectl get`, including:

- Pod metadata
- Labels and annotations
- Node assignment
- Container information
- Images
- Container state
- Conditions
- Volumes
- Events related to the resource

This makes `kubectl describe` especially useful when a Pod is not starting or is stuck in an unexpected state.

---

# 3. `kubectl logs`

`kubectl logs` displays output produced by a container.

### Commands

```bash
kubectl logs image-demo
```

It can also be written as:

```bash
kubectl logs pod/image-demo
```

For a specific container in a multi-container Pod:

```bash
kubectl logs <pod-name> -c <container-name>
```

### What logs are useful for

Logs help investigate what the application or container is doing at runtime.

They can reveal:

- Application messages
- Startup information
- Runtime errors
- Configuration problems
- Application crashes

For example, the `crash-demo` Pod produced:

```text
Application starting...
Something went wrong!
```

This showed that the container itself was exiting because of its command.

### Screenshot

![kubectl logs](./images/kubectl-logs.png)

---

# 4. `kubectl exec`

`kubectl exec` allows commands to be executed inside a running container.

### Command used

```bash
kubectl exec -it exec-demo -- ls
```

This listed the filesystem inside the `exec-demo` Pod.

The output included:

```text
bin
dev
docker-entrypoint.sh
etc
home
lib
opt
root
sbin
tmp
usr
var
```

The `--` separates kubectl arguments from the command that should run inside the container.

### Interactive vs non-interactive

The commonly used options are:

```text
-i  Keep standard input open
-t  Allocate a terminal
```

Therefore:

```bash
kubectl exec -it exec-demo -- sh
```

can be used to open an interactive shell when the container provides one.

---

# 5. `kubectl cp`

`kubectl cp` is used to copy files between a local machine and a Kubernetes container.

## Homework 1

Copy a file from the `exec-demo` Pod into the current repository.

### Command

```bash
kubectl cp exec-demo:/docker-entrypoint.sh ./docker-entrypoint.sh
```

This copies:

```text
Pod:
exec-demo:/docker-entrypoint.sh
```

to:

```text
Local repository:
./docker-entrypoint.sh
```

### General syntax

```bash
kubectl cp <pod-name>:<path-inside-pod> <local-path>
```

The direction can also be reversed to copy a local file into a Pod:

```bash
kubectl cp <local-path> <pod-name>:<path-inside-pod>
```

---

# 6. Kubernetes Events

Kubernetes Events are records of important activity involving resources in the cluster.

They can show things such as:

- Pod scheduling
- Container creation
- Container startup
- Image pulling
- Container termination
- Failed scheduling
- Warnings
- Resource lifecycle activity

### Command

```bash
kubectl events
```

An equivalent resource-based command is:

```bash
kubectl get events
```

Both are used to inspect Kubernetes Events, although their command interfaces are different.

The output contains fields such as:

```text
LAST SEEN
TYPE
REASON
OBJECT
MESSAGE
```

### Event types

Common event types include:

```text
Normal
Warning
```

`Normal` events describe expected activity such as scheduling, pulling an image, creating a container, or starting a container.

`Warning` events indicate a problem or condition that may require investigation.

### Example from the session

For `events-demo`, events showed:

```text
Scheduled
Pulled
Created
Started
```

This represents the Pod progressing through its normal startup lifecycle.

The session also showed warning events from earlier workloads, such as failed scheduling and metrics-related problems.

### Screenshots

![kubectl events 1](./images/kubectl-events-1.png)

![kubectl events 2](./images/kubectl-events-2.png)

---

# 7. Watching Events

Events can be watched continuously:

```bash
kubectl events --watch
```

This allows new events to appear as they happen.

> Note: `--watch` is one option. Writing `-- watch` with a space is different and should not be used as the option syntax.

### Screenshot

![kubectl events watch](./images/kubectl-events-watch.png)

---

# 8. Sorting Events

Events can be sorted using the Kubernetes field selector:

```bash
kubectl get events --sort-by=.lastTimestamp
```

This helps organize events according to their timestamp.

The correct flag is:

```text
--sort-by
```

not:

```text
--sortby
```

The session demonstrated the error produced by the incorrect form and then the successful command using `--sort-by`.

### Screenshot

![kubectl events sorted](./images/kubectl-events-sorted.png)

---

# 9. Events vs Logs

| Events | Logs |
|---|---|
| Describe Kubernetes-level activity | Show container/application output |
| Generated by Kubernetes | Produced by the application/container |
| Useful for resource lifecycle information | Useful for runtime/application debugging |
| Can show scheduling, creation, startup and termination | Can show application messages and errors |
| Command: `kubectl events` | Command: `kubectl logs <pod-name>` |

### Simple distinction

**Events tell us what happened to Kubernetes resources.**

**Logs tell us what the container/application produced while running.**

A useful troubleshooting combination is therefore:

```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl events
```

`describe` gives resource details and related events, while `logs` gives the application's/container's output.

---

# 10. CrashLoopBackOff / Container Crash Troubleshooting

The `06-crashloopbackoff` exercise intentionally created a broken Pod.

### Create the broken Pod

```bash
kubectl apply -f broken-pod.yaml
```

Then inspect its state:

```bash
kubectl get pods
```

The Pod entered an error state and had a restart count.

### Inspect the logs

```bash
kubectl logs pod/crash-demo
```

Output:

```text
Application starting...
Something went wrong!
```

This showed that the container command exited with a failure.

### Attempting to apply the fixed Pod

```bash
kubectl apply -f fixed-pod.yaml
```

Kubernetes rejected the update because some Pod specification fields are immutable after creation.

The error indicated that fields other than a limited set of mutable fields could not be changed.

### Correct solution

Delete the old Pod:

```bash
kubectl delete pod/crash-demo
```

Then create it again from the fixed manifest:

```bash
kubectl apply -f fixed-pod.yaml
```

Finally verify:

```bash
kubectl get pods
```

The fixed `crash-demo` Pod reached:

```text
1/1 Running
```

### Key concept

For a standalone Pod, changing many fields of the Pod specification is not allowed after creation.

A common troubleshooting approach is:

```text
Broken Pod
    ↓
Check status
    ↓
Check logs
    ↓
Identify the problem
    ↓
Delete/recreate the Pod with corrected configuration
```

For production workloads, controllers such as Deployments are normally used so corrected Pod templates can be rolled out rather than manually managing individual Pods.

---

# 11. ImagePullBackOff / ErrImagePull Troubleshooting

The `07-imagepullbackoff` exercise created a Pod with an invalid/unavailable image.

### Create the broken Pod

```bash
kubectl apply -f broken-pod.yaml
```

Check the Pod:

```bash
kubectl get pods
```

The Pod showed:

```text
ErrImagePull
```

`ErrImagePull` indicates that Kubernetes could not pull the requested container image.

Repeated image-pull failures can lead to:

```text
ImagePullBackOff
```

where Kubernetes backs off before retrying the image pull.

### Fix

The broken Pod was deleted:

```bash
kubectl delete pod/image-demo
```

Then the corrected manifest was applied:

```bash
kubectl apply -f fixed-pod.yaml
```

Verify:

```bash
kubectl get pods
```

The corrected Pod reached:

```text
1/1 Running
```

Logs were then checked:

```bash
kubectl logs image-demo
```

The NGINX startup output confirmed that the container started successfully.

### Common causes of image-pull failures

Examples include:

- Incorrect image name
- Incorrect image tag
- Image does not exist in the registry
- Private registry authentication problems
- Registry/network access problems

---

# 12. Pending Pod Troubleshooting

The `08-pending-pods` exercise created a Pod that remained in:

```text
Pending
```

### Create the broken Pod

```bash
kubectl apply -f broken-pod.yaml
```

Check:

```bash
kubectl get pods
```

The Pod showed:

```text
pending-demo    0/1    Pending
```

A `Pending` Pod has not successfully reached the stage where its container is running.

Possible reasons include:

- No suitable node
- Insufficient resources
- Scheduling constraints
- Missing or unbound storage
- Taints/tolerations mismatch
- Other scheduling requirements

### Fix

The broken Pod was deleted:

```bash
kubectl delete pod/pending-demo
```

Then the corrected manifest was applied:

```bash
kubectl apply -f fixed-pod.yaml
```

Verify:

```bash
kubectl get pods
```

The Pod reached:

```text
1/1 Running
```

For deeper investigation of a Pending Pod, use:

```bash
kubectl describe pod pending-demo
```

and inspect the Events section.

---

# 13. Service and DNS Troubleshooting

The `09-service-dns-troubleshooting` exercise demonstrated how a Service connects clients to backend Pods.

### Create the application

```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f dns-test-pod.yaml
```

Check the resources:

```bash
kubectl get pods
kubectl get all
```

The `web` Deployment created two Pods and the `web-service` Service was created as a ClusterIP Service.

### Inspect the Service

```bash
kubectl get svc
```

A Service provides a stable virtual IP and DNS name for accessing a group of Pods selected by its selector.

### Inspect endpoints

```bash
kubectl get endpoints web-service
```

The session showed:

```text
web-service   10.244.0.16:80,10.244.0.17:80
```

This means the Service had backend endpoints corresponding to the two running `web` Pods.

---

# 14. Broken Service and Empty Endpoints

A deliberately broken Service was created:

```bash
kubectl apply -f broken-service.yaml
```

Then:

```bash
kubectl get svc
```

and:

```bash
kubectl get endpoints broken-service
```

The result was:

```text
broken-service   <none>
```

### What does `<none>` mean?

It means the Service currently has no matching backend endpoints.

One common cause is a mismatch between:

```text
Service selector
```

and:

```text
Pod labels
```

If the Service selector does not match the labels on the Pods, Kubernetes cannot associate those Pods with the Service.

A useful troubleshooting sequence is:

```bash
kubectl get svc
kubectl get pods --show-labels
kubectl get endpoints <service-name>
kubectl describe svc <service-name>
```

The important relationship is:

```text
Service
   ↓
Selector
   ↓
Matching Pod labels
   ↓
Endpoints / EndpointSlices
   ↓
Backend Pods
```

---

# 15. Endpoints and EndpointSlice

The session produced this warning:

```text
Warning: v1 Endpoints is deprecated in v1.33+;
use discovery.k8s.io/v1 EndpointSlice
```

This means the older `Endpoints` API is deprecated in the Kubernetes version being used.

The Service networking model now uses **EndpointSlices** for scalable representation of backend endpoints.

For modern Kubernetes inspection, EndpointSlices can be viewed with:

```bash
kubectl get endpointslices
```

or for a specific Service, by inspecting its associated EndpointSlice resources.

The important troubleshooting idea remains the same:

```text
Service → selector → matching Pods → backend endpoints
```

---

# 16. Event and Log Troubleshooting Workflow

A useful troubleshooting flow is:

```text
1. Check Pod status
        ↓
2. Describe the Pod
        ↓
3. Check Pod logs
        ↓
4. Check Kubernetes events
        ↓
5. Investigate the specific failure
        ↓
6. Apply the appropriate fix
        ↓
7. Verify the resource is healthy
```

Typical commands:

```bash
kubectl get pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl events
```

For live event monitoring:

```bash
kubectl events --watch
```

For Service troubleshooting:

```bash
kubectl get svc
kubectl get endpoints <service-name>
kubectl get endpointslices
```

---

# 17. Homework

## Homework 1 — `kubectl cp`

From the `04-kubectl-exec` folder, copy a file from the running `exec-demo` Pod into the local repository.

### Command

```bash
kubectl cp exec-demo:/docker-entrypoint.sh ./docker-entrypoint.sh
```

The purpose is to practice copying data from a Kubernetes container to the local machine.

---

## Homework 2 — Events and Logs

Create documentation explaining:

1. What Kubernetes Events are.
2. What Kubernetes Logs are.
3. The commands used to view them.
4. The difference between Events and Logs.
5. Include screenshots showing the commands and their outputs.

### Events command

```bash
kubectl events
```

### Logs command

```bash
kubectl logs <pod-name>
```

### Difference

```text
Events → Kubernetes resource/activity information

Logs   → Container/application runtime output
```

The screenshots included in this session document the Events and Logs work.

---

# 18. Screenshot Reference

All screenshots are stored in the `images` folder.

```text
images/
├── kubectl-get.png
├── kubectl-events-1.png
├── kubectl-events-2.png
├── kubectl-events-watch.png
├── kubectl-events-sorted.png
└── kubectl-logs.png
```

---

# Key Commands

```bash
kubectl get pods
kubectl get pods -w

kubectl describe pod get-demo

kubectl logs image-demo

kubectl exec -it exec-demo -- ls

kubectl cp exec-demo:/docker-entrypoint.sh ./docker-entrypoint.sh

kubectl events
kubectl events --watch
kubectl get events --sort-by=.lastTimestamp

kubectl get all

kubectl get svc
kubectl get endpoints web-service
kubectl get endpoints broken-service
kubectl get endpointslices
```

---

# Summary

This session covered the main `kubectl` commands used for Kubernetes inspection and troubleshooting:

- `kubectl get` — inspect resource status
- `kubectl describe` — inspect detailed resource information
- `kubectl logs` — inspect container output
- `kubectl exec` — execute commands inside a container
- `kubectl cp` — copy files between a Pod and the local machine
- `kubectl events` — inspect Kubernetes resource events

It also covered practical troubleshooting of:

- Container crashes and restart behavior
- Immutable Pod specification fields
- `ErrImagePull` and `ImagePullBackOff`
- Pending Pods and scheduling
- Services and ClusterIP
- Service selectors and Pod labels
- Service endpoints
- Empty endpoints (`<none>`)
- EndpointSlice and the deprecated Endpoints API
- Using Events, Logs, and `describe` together during troubleshooting

The two homework tasks were also included: practicing `kubectl cp` and documenting the difference between Kubernetes Events and container Logs.

---

# Kubernetes Troubleshooting Mini Project

## Screenshots

### 1. Deployment and Pods

![Deployment and Pods](./images/01-deployment-and-pods.png)

### 2. Broken Pod and Service Endpoints

![Broken Pod and Service Endpoints](./images/02-broken-pod-and-service-endpoints.png)

### 3. Pod Exec and Service Description

![Pod Exec and Service Description](./images/03-pod-exec-and-service-describe.png)

### 4. Troubleshooting and Service Fix

![Troubleshooting and Service Fix](./images/04-troubleshooting-and-service-fix.png)

## Project Objective

This mini project demonstrates a practical Kubernetes troubleshooting workflow:

```text
Deploy
  ↓
Observe
  ↓
Break
  ↓
Investigate
  ↓
Find Root Cause
  ↓
Fix
  ↓
Verify
```

The project uses an Nginx Deployment, a ClusterIP Service, and an intentionally broken Pod.

## 1. Project Files

```text
mini-project/
├── deployment.yaml
├── service.yaml
├── broken-pod.yaml
├── README.md
└── images/
    ├── 01-deployment-and-pods.png
    ├── 02-broken-pod-and-service-endpoints.png
    ├── 03-pod-exec-and-service-describe.png
    └── 04-troubleshooting-and-service-fix.png
```

## 2. Deploy The Application

Applied the Deployment:

```bash
kubectl apply -f deployment.yaml
```

Then checked the Pods:

```bash
kubectl get pods
```

The Deployment created two Nginx Pods, both reaching the Running state.

## 3. Test The Application

A running application Pod was accessed using:

```bash
kubectl exec -it <pod-name> -- bash
```

Inside the container:

```bash
curl localhost
```

The Nginx welcome page was returned, confirming that the application itself was working correctly.

## 4. Investigate The Service

The Service was checked using:

```bash
kubectl get service
```

and:

```bash
kubectl describe service troubleshooting-service
```

The Service configuration showed:

```yaml
Selector:    app=troubleshooting-app
TargetPort:  80/TCP
```

The Service initially had endpoints corresponding to the two application Pods.

## 5. Check Service Endpoints

The endpoints were checked with:

```bash
kubectl get endpoints troubleshooting-service
```

The working Service showed two Pod IP addresses:

```text
10.244.0.19:80
10.244.0.20:80
```

This confirms that the Service selector successfully matched the application Pods.

> **Note:** Kubernetes displayed a warning that the v1 Endpoints API is deprecated in Kubernetes v1.33+ and recommends `discovery.k8s.io/v1` EndpointSlice.

## 6. Broken Pod Investigation

The intentionally broken Pod was created with:

```bash
kubectl apply -f broken-pod.yaml
```

The Pod used the image:

```yaml
image: nginx:this-tag-does-not-exist
```

The Pod entered an image-pull failure state.

```bash
kubectl get pod project-broken-pod
```

To investigate the root cause:

```bash
kubectl describe pod project-broken-pod
```

The Events section showed:

```text
Failed to pull image "nginx:this-tag-does-not-exist"
```

and:

```text
Error: ErrImagePull
```

The root cause was that the specified image tag does not exist.

## 7. Broken Pod Root Cause

| Question | Answer |
|---|---|
| Pod status | ErrImagePull / image pull failure |
| Actual error | Kubernetes failed to pull the specified image |
| Command used | `kubectl describe pod project-broken-pod` |
| Problem with image | `nginx:this-tag-does-not-exist` is not a valid existing image tag |
| Fix | Replace it with a valid image such as `nginx:1.27` |

## 8. Service Selector Troubleshooting

The Service was intentionally configured with an incorrect selector during troubleshooting.

The working selector is:

```yaml
selector:
  app: troubleshooting-app
```

When the selector does not match the Pod labels, the Service has no backend endpoints.

This can be checked using:

```bash
kubectl get endpoints troubleshooting-service
```

The broken state showed:

```text
troubleshooting-service   <none>
```

This means the Service could not find any matching Pods.

## 9. Finding The Service Root Cause

The Service was inspected with:

```bash
kubectl describe service troubleshooting-service
```

The important relationship is:

```text
Pod label
    ↓
app=troubleshooting-app

Service selector
    ↓
app=troubleshooting-app
```

When these values do not match, Kubernetes does not add the Pods as Service endpoints.

After restoring the correct Service configuration, the Service again showed the Pod IP addresses as endpoints.

## 10. Troubleshooting Table

| Problem | What I Saw | Command I Used | Root Cause | Fix |
|---|---|---|---|---|
| Broken Pod | ErrImagePull | `kubectl describe pod project-broken-pod` | Invalid image tag | Use a valid Nginx image |
| Service Problem | `<none>` endpoints | `kubectl get endpoints troubleshooting-service` | Selector did not match Pod labels | Correct the Service selector |
| Image Problem | Image pull failure | `kubectl describe pod project-broken-pod` | `nginx:this-tag-does-not-exist` does not exist | Change to a valid image tag |

## 11. Important Troubleshooting Commands

**Pods**

```bash
kubectl get pods
kubectl get pods -o wide
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl exec -it <pod-name> -- bash
```

**Events**

```bash
kubectl get events
kubectl events
```

**Services**

```bash
kubectl get service
kubectl describe service <service-name>
kubectl get endpoints <service-name>
```

**Labels**

```bash
kubectl get pods --show-labels
```

## 12. Troubleshooting Questions

**1. What does `kubectl get` tell us?**

It provides a quick overview of Kubernetes resources and their current status.

**2. What is the difference between `get` and `describe`?**

`get` provides a concise resource summary, while `describe` provides detailed information including configuration, status, and events.

**3. Why do we use `kubectl logs`?**

To inspect the output produced by a container and help identify application-level problems.

**4. When would you use `kubectl exec`?**

When direct interaction with a running container is required, such as testing files, commands, networking, or application responses.

**5. What does `CrashLoopBackOff` mean?**

It indicates that a container is repeatedly crashing and Kubernetes is progressively increasing the delay before restarting it.

**6. What does `ImagePullBackOff` mean?**

It means Kubernetes failed to pull a container image and is backing off before retrying.

**7. Why can a Pod remain `Pending`?**

A Pod can remain Pending when Kubernetes cannot successfully schedule it, for example because of insufficient resources or scheduling constraints.

**8. Why can a Service have no endpoints?**

Usually because the Service selector does not match the labels on any Pods.

**9. What is the relationship between a Service selector and Pod labels?**

The Service selector determines which Pods become Service backends. The selector must match the corresponding Pod labels.

**10. What is Kubernetes DNS?**

Kubernetes DNS allows applications inside the cluster to discover Services using DNS names instead of directly using Service IP addresses.

## 13. Final Troubleshooting Mindset

When something breaks, do not guess.

```text
GET
 ↓
DESCRIBE
 ↓
EVENTS
 ↓
LOGS
 ↓
EXEC
 ↓
TEST
 ↓
FIX
 ↓
VERIFY
```

This project demonstrates how Kubernetes troubleshooting can be approached systematically by observing the resource, finding evidence, identifying the root cause, applying a fix, and verifying the result.

## Author

**Kiran N**

Roll No.: **24BCS10446**
