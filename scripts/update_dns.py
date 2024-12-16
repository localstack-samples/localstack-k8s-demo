#!/usr/bin/env python

import time
import re
from typing import cast
from datetime import datetime, timezone
from kubernetes import config
from kubernetes import client as k8s_client


class KubernetesClient:
    def __init__(self, namespace: str, client: k8s_client.CoreV1Api | None = None):
        self.namespace = namespace
        if client:
            self.client = client
        else:
            config.load_kube_config()
            self.client = k8s_client.CoreV1Api()

    def get_localstack_service_ip_address(self) -> str:
        res = self.client.read_namespaced_service(
            name="localstack", namespace=self.namespace
        )
        return res.spec.cluster_ip

    def update_dns_configuration(self, upstream_ip_address: str):
        config_map = self.client.read_namespaced_config_map(
            name="coredns", namespace="kube-system"
        )
        altered_config_data = config_map.data["Corefile"].replace(
            "forward . /etc/resolv.conf", f"forward . {upstream_ip_address}"
        )
        config_map.data["Corefile"] = altered_config_data
        self.client.replace_namespaced_config_map(
            name="coredns", namespace="kube-system", body=config_map
        )

    def reset_dns_configuration(self):
        config_map = self.client.read_namespaced_config_map(
            name="coredns", namespace="kube-system"
        )
        corefile_contents = config_map.data["Corefile"]
        if "forward . /etc/resolv.conf" in corefile_contents:
            return

        forward_regex = re.compile(r"forward\s+\.\s+(?:\d+\.){3}\d+")
        altered_config_data = forward_regex.sub("forward . /etc/resolv.conf", corefile_contents)
        config_map.data["Corefile"] = altered_config_data
        self.client.replace_namespaced_config_map(
            name="coredns", namespace="kube-system", body=config_map
        )

    def restart_coredns(self):
        apps_client = k8s_client.AppsV1Api()
        body = {
            "spec": {
                "template": {
                    "metadata": {
                        "annotations": {
                            "kubectl.kubernetes.io/restartedAt": datetime.now(
                                tz=timezone.utc
                            ).isoformat()
                        }
                    }
                }
            }
        }
        deployment_name = "coredns"
        apps_client.patch_namespaced_deployment(
            name=deployment_name, namespace="kube-system", body=body
        )

        # wait for deployment status
        self._wait_for_deployment_ready(deployment_name, namespace="kube-system")

    def _wait_for_deployment_ready(self, name: str, namespace: str, timeout: int = 60):
        apps_client = k8s_client.AppsV1Api()
        start_time = time.time()
        while True:
            deployment = apps_client.read_namespaced_deployment_status(name=name, namespace=namespace)
            conditions = deployment.status.conditions or []
            for condition in conditions:
                if condition.type == "Available" and condition.status == "True":
                    return

            elapsed = time.time() - start_time
            if elapsed >= timeout:
                raise RuntimeError("Timed out waiting for deployment to be ready")

            time.sleep(1)

    def assert_dns_update(self):
        batch_client = k8s_client.BatchV1Api()

        job_name = "debug"
        job_manifest = {
            "apiVersion": "batch/v1",
            "kind": "Job",
            "metadata": {"name": job_name},
            "spec": {
                "template": {
                    "spec": {
                        "containers": [
                            {
                                "name": "debug",
                                "image": "ghcr.io/simonrw/docker-debug:main",
                                "args": ["sh", "-c", "dig +short localhost.localstack.cloud | grep -qv 127.0.0.1"],
                            }
                        ],
                        "restartPolicy": "Never",
                    },
                },
                "backoffLimit": 4,
            },
        }

        # Create the job
        try:
            batch_client.create_namespaced_job(
                namespace=self.namespace, body=job_manifest
            )
            # wait for job termination
            while True:
                job = cast(k8s_client.V1Job, batch_client.read_namespaced_job(
                    namespace=self.namespace, name=job_name
                ))
                if not job.status:
                    continue

                if job.status.succeeded:
                    break

                for condition in (job.status.conditions or []):
                    if condition.type == "Failed" and condition.status == "True":
                        raise RuntimeError("Job failed")

                time.sleep(1)

            # get job pods
            pods = cast(k8s_client.V1PodList, self.client.list_namespaced_pod(
                namespace=self.namespace,
                label_selector=f"batch.kubernetes.io/job-name={job_name}",
            ))

            pod = (pods.items or [])[0]
            ip_address = self.client.read_namespaced_pod_log(
                name=pod.metadata.name, namespace=self.namespace
            ).strip()

            for pod in pods.items or []:
                self.client.delete_namespaced_pod(namespace=self.namespace, name=pod.metadata.name)

            assert ip_address != "127.0.0.1"

        finally:
            try:
                batch_client.delete_namespaced_job(
                    namespace=self.namespace, name=job_name
                )
            except:
                pass


client = KubernetesClient("default")
ip = client.get_localstack_service_ip_address()
client.update_dns_configuration(ip)
client.restart_coredns()
client.assert_dns_update()
