// 私钥：使用 RSA PEM（ssh-keygen -t rsa -b 4096 -m PEM）。整段替换三引号内内容，与 jenkins_rsa 文件一致。
// 勿将含真实私钥的脚本提交到 Git；可只粘到 Jenkins「Pipeline script」。

pipeline {
  agent any

  environment {
    KEY_FILE = "${WORKSPACE}/.ci_gerrit_ssh"
  }

  stages {
    stage('Prepare Gerrit key') {
      steps {
        script {
          def GERRIT_SSH_PRIVATE_KEY = ('''-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAABFwAAAAdzc2gtcn
NhAAAAAwEAAQAAAQEAlUwT1jdqbQTruqNDU6I3OaGAwrO+Fa84z1T8TmBysxyixoemBLCz
+o28pv7yBImZcuA4/jTzRlbXOspmtzr/rywXPTk+ITAycNpEMM6g54sw9zjyKAiG60XyBK
5BvflweFIXRAsK0WdqMOHXmhimX78zLcl/rI0vjYiyo2dd5lDM4aDzI0Sap5CS7rRHPeP/
4iqzbQqbmp9zcSnwuYVxN27or5l8VVkmaWtf3gXs19iwVmDXQOezpMfKO1xWgqhK1u1my3
CIw9m3B1wCh+INZUy3PyKU3iDsdWWC4zzMADD6N9T106nsRBLE3VAMOxyS+oOGU64zEhpG
MUtBgq9A1wAAA8iETiQxhE4kMQAAAAdzc2gtcnNhAAABAQCVTBPWN2ptBOu6o0NTojc5oY
DCs74VrzjPVPxOYHKzHKLGh6YEsLP6jbym/vIEiZly4Dj+NPNGVtc6yma3Ov+vLBc9OT4h
MDJw2kQwzqDnizD3OPIoCIbrRfIErkG9+XB4UhdECwrRZ2ow4deaGKZfvzMtyX+sjS+NiL
KjZ13mUMzhoPMjRJqnkJLutEc94//iKrNtCpuan3NxKfC5hXE3buivmXxVWSZpa1/eBezX
2LBWYNdA57Okx8o7XFaCqErW7WbLcIjD2bcHXAKH4g1lTLc/IpTeIOx1ZYLjPMwAMPo31P
XTqexEEsTdUAw7HJL6g4ZTrjMSGkYxS0GCr0DXAAAAAwEAAQAAAQEAge8FMKFoCVuIARYI
CWibYZfSZSFjpKGr8p3HPDsqeAHLFLeH4HsdGEl0z24AmbxbhSPp1iulMilwBeWTQZKiZg
UccJc6IE4/CAKd6FBcr0dvpSm1buwE6Awm1rYF112Y6c6gGwL1NkwnmkVji+Q6IAhadVXx
vO3fXfGDbz0N9tw1NVLwlsHj4gjb99rAQnjhOnvjziBGCA7/CLyGvxgwntZgKGXtw9s7/Q
FnBtaKYtOW9LpEWKtBYdYo2+lT2SEl8+VNMokZI1ZURxR09/xuXvnwuoX4/dbw353xjEvn
/dbzti7u1SuA+Q9y95dsDPlelVcCT4+MvQNaM4IKh+c8gQAAAIEAhp8+Wo1aUwm7AJvXGm
J1EZmQPxOSzg+YaR6Yyqxy8aY0PR8U+UHuGwopia5IBlq/vbGICZ6VGKjA/4NzpVfPJudh
yZl1gXQMquriJodOciEm8eDvo503waTf7t1UqekhKudEs4bh/5V8KWjOYinkagEpB7G8Js
rifsvyqVQx/P0AAACBAMU0iOVGo4S3adFJl/DiXWyfgZuPKq++9uo1l3KWhZXSWboMq1z5
wrsMJddPVwFvThza5Xb9SD2vvqvywyDTv4l8OBZpikz8f4M5+eyTPvYkpIygTiofKD5zCh
p+LhpIB/0LQ0YMzSfMfNEXPVQ/YJ8+XBqWJGJjJ3TdWhyDfb3BAAAAgQDBzwQXLAVY53H5
4Df0E23kDrG8hmI1GMxMbRya32ND9qb7CQn3noNJUcQs8f5hMrMY+zozbRnoABaA+hDK/n
N9HSHGERck5lsENx/iBhlsc9FbaSs21Jr6fNJQ42yB9wBShfW/wTbtliddUhx8oxaM+xYj
T1U4QfjJQ1WI04FUlwAAAAoyNTE4MkDUzLqtAQIDBAUGBw==
-----END OPENSSH PRIVATE KEY-----''').stripIndent().trim() + '\n'

          writeFile file: env.KEY_FILE, text: GERRIT_SSH_PRIVATE_KEY
        }
        sh 'chmod 600 "$KEY_FILE"'
      }
    }

    stage('Checkout') {
      steps {
        sh '''
          set -e
          # 与 Gerrit Trigger 事件一致：必须用 GERRIT_PROJECT，勿写死成其它仓库（如 Court_AI）
          PROJECT="${GERRIT_PROJECT:-SECP-frontend}"
          GUSER="${GERRIT_SSH_USER:-23301015}"
          export GIT_SSH_COMMAND="ssh -i $KEY_FILE -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -p 29418"
          rm -rf .git
          git init
          git remote add origin "ssh://${GUSER}@gerrit.lilingkun.com:29418/${PROJECT}"
          echo "Gerrit 仓库: ${PROJECT}（来自 GERRIT_PROJECT，未设置则默认 SECP-frontend）"
          if [ -n "$GERRIT_REFSPEC" ]; then
            REFSPEC="$GERRIT_REFSPEC"
            echo "使用 GERRIT_REFSPEC: $REFSPEC"
          else
            REFSPEC="refs/heads/master"
            echo "GERRIT_REFSPEC 未设置（立即构建），回退: $REFSPEC"
          fi
          git fetch --depth=1 origin "$REFSPEC"
          git checkout -qf FETCH_HEAD
        '''
      }
    }
  }

  post {
    success {
      script {
        // 仅 --message：多数站点默认允许评论；Verified 需在 Gerrit 权限里给本 SSH 用户开放，否则会报 "Applying label Verified is restricted"
        def msg = "Jenkins 构建成功 #${env.BUILD_NUMBER}"
        def ws = env.WORKSPACE
        def msgPath = "${ws}/.ci_gerrit_verify_msg.txt"
        def runPath = "${ws}/.ci_gerrit_vote.sh"
        writeFile file: msgPath, text: msg, encoding: 'UTF-8'
        def bash = '''#!/usr/bin/env bash
set -e
MSG=$(cat '__MSGPATH__')
GUSER="${GERRIT_SSH_USER:-23301015}"
if [ -n "$GERRIT_PATCHSET_REVISION" ] && [ -f "$KEY_FILE" ]; then
  ssh -i "$KEY_FILE" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -p 29418 \
    "${GUSER}@gerrit.lilingkun.com" \
    "gerrit review --message $(printf %q "$MSG") $(printf %q "$GERRIT_PATCHSET_REVISION")"
fi
rm -f '__MSGPATH__'
'''.replace('__MSGPATH__', msgPath)
        writeFile file: runPath, text: bash, encoding: 'UTF-8'
        sh "chmod +x '${runPath}' && bash '${runPath}'"
      }
    }
    failure {
      script {
        def msg = "Jenkins 构建失败 #${env.BUILD_NUMBER}"
        def ws = env.WORKSPACE
        def msgPath = "${ws}/.ci_gerrit_verify_msg.txt"
        def runPath = "${ws}/.ci_gerrit_vote.sh"
        writeFile file: msgPath, text: msg, encoding: 'UTF-8'
        def bash = '''#!/usr/bin/env bash
set -e
MSG=$(cat '__MSGPATH__')
GUSER="${GERRIT_SSH_USER:-23301015}"
if [ -n "$GERRIT_PATCHSET_REVISION" ] && [ -f "$KEY_FILE" ]; then
  ssh -i "$KEY_FILE" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -p 29418 \
    "${GUSER}@gerrit.lilingkun.com" \
    "gerrit review --message $(printf %q "$MSG") $(printf %q "$GERRIT_PATCHSET_REVISION")"
fi
rm -f '__MSGPATH__'
'''.replace('__MSGPATH__', msgPath)
        writeFile file: runPath, text: bash, encoding: 'UTF-8'
        sh "chmod +x '${runPath}' && bash '${runPath}'"
      }
    }
    cleanup {
      sh 'rm -f "$KEY_FILE" "${WORKSPACE}/.ci_gerrit_verify_msg.txt" "${WORKSPACE}/.ci_gerrit_vote.sh" || true'
    }
  }
}
