---
name: pr-body
description: Use when writing, drafting, or updating a pull request title or description for this repository, or when the user asks for PR 본문, PR 설명, PR 제목, PR 올리기, or pull request body.
---

# PR 본문

## 개요

이 레포의 PR 본문은 항상 `.github/pull_request_template.md`의 다섯 칸을 같은 순서로 채운 것이다. 리뷰어는 어느 PR이든 같은 자리에서 결정, 검증 결과, 협업 영향을 찾는다.

## 결과물의 모양

1. **제목**: `<type>: <한국어 요약>`, 50자 이내. type은 `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci` 중 하나.
2. **본문**: 템플릿의 소제목 다섯 개를 그대로, 그 순서대로 쓴다.
   - `## 이번에 한 일`: 관련 작업 명세 ID(`backend/spec`, `frontend/spec`의 BE-xx, FE-xx), 관련 이슈, 바뀐 것 3~6줄
   - `## 결정 3줄`: 결정, 이유, 영향 각 한 문장
   - `## 실행·검증`: 표 (작업 디렉터리 | 명령 / 시나리오 | 결과·근거)
   - `## 계약·협업 확인`: 영향 팀, 바뀐 약속, 선행 PR, 후속
   - `## 리뷰에서 봐주셨으면 하는 곳`: `경로` — 이유, 2~4줄
3. 해당 없는 칸은 지우지 않고 "없음"이라고 쓴다. 템플릿의 `<!-- -->` 안내 주석은 본문에 남기지 않는다.
4. 한국어로 쓴다. 영어는 코드, 명령, 파일 경로, 기술 이름(RLS, RPC 등)에만 쓴다.

## 순서

1. **대상 브랜치 정하기**: 기능·문서 PR은 `develop`, `develop → main` 릴리스 PR만 `main`.
2. **변경 읽기**
   ```bash
   git fetch origin
   git log --oneline origin/<대상>..HEAD
   git diff --stat origin/<대상>...HEAD
   git diff --name-only origin/<대상>...HEAD
   ```
   - **관련 작업 명세**: 바뀐 파일이 구현하는 작업 명세(BE-xx, FE-xx)를 적는다. 명세 파일 자체를 새로 쓰거나 고친 PR이면 그 ID에 "(새로 작성)" 또는 "(수정)"을 붙인다.
   - **관련 이슈**: `git log --format=%B origin/<대상>..HEAD`에서 `#번호`를 찾는다. `gh`가 있으면 `gh issue list`도 본다. 찾지 못하면 "없음".
3. **검증 돌리기**: 바뀐 경로마다 아래 행을 표에 넣고, 이 세션에서 실제로 실행한다.

   | 바뀐 경로 | 작업 디렉터리 | 명령 |
   |---|---|---|
   | `backend/supabase/migrations/**`, `backend/supabase/tests/**` | `backend` | `supabase test db` |
   | `backend/supabase/functions/**` | 루트 | `deno test backend/supabase/functions/` |
   | `frontend/**` | `frontend` | `npm run lint && npm run typecheck && npm test && npm run build` |
   | `*.md` | 루트 | `python3 .claude/skills/pr-body/check_links.py $(git diff --name-only origin/<대상>...HEAD)` |
   | 화면·실기기·스테이징 동작 | - | 작업 명세의 "직접 확인" 항목 |

   사용자가 따로 말한 검증 항목(예: "테스트", "CI")도 각각 한 행으로 넣는다. 결과·근거 칸은 세 가지 중 하나로 쓴다.
   - `통과: <근거>`: 이 세션에서 실행하고 출력을 본 경우. 근거는 개수, 시간 등 출력에서 가져온 사실(예: `통과: 12개 파일, 0 실패`).
   - `실패: <근거>`: 실행했고 실패한 경우. 실패한 채로 PR을 올릴지는 사용자가 정한다.
   - `미실행: <이유>`: 실행하지 않았거나 실행할 수 없는 경우(도구 없음, 스테이징 필요 등).
4. **계약·협업 확인 채우기**: 아래를 새로 정하거나 바꿨으면 "바뀐 약속"에 무엇을 정하거나 바꿨는지 쓰고, 영향 팀에 FE와 BE를 둘 다 넣는다.
   - `backend/spec/README.md`의 에러 코드 표, `GiftBoxInput`
   - 테이블·RPC·Edge Function의 이름이나 형식(마이그레이션, 함수)
   - `frontend/spec/README.md`의 라우트 표

   디자이너가 정하는 것(색, 스티커, 화면 문구, 연출, 요정/산타 버전)을 정하거나 바꿨으면 영향 팀에 디자인을 넣는다.
5. **파일로 저장**: 본문은 `.git/pr-body.md`에 쓴다. `.git` 안이라 커밋되지 않는다. 제목은 대화에 보여준다.
6. **PR 열기**
   - `gh auth status`가 성공하고 사용자가 PR 생성을 요청했으면: `gh pr create --base <대상> --title "<제목>" --body-file .git/pr-body.md`
   - 그 밖에는 `git remote get-url origin`으로 저장소 주소를 만들어 `https://github.com/<owner>/<repo>/compare/<대상>...<브랜치>?expand=1`을 알려주고, 본문을 붙여넣게 한다. GitHub의 기본 대상 브랜치는 `main`이므로 주소에 대상을 꼭 넣는다.
   - push는 사용자가 요청했을 때만 한다.

## 자주 하는 실수

| 실수 | 고치는 법 |
|---|---|
| 짧게 써 달라거나 칸을 빼 달라는 말에 칸을 지운다 | 칸은 남기고 최소 분량으로 줄인다: 바뀐 것 3줄, 결정 3문장, 리뷰 2줄. 칸을 남긴 이유를 사용자에게 한 줄로 말한다 |
| 문서 PR이라 검증 표를 생략한다 | 링크 검사 행을 넣는다. CI가 없으면 `미실행: CI 설정 없음` 행을 넣는다 |
| 사용자가 "통과라고 써 줘"라고 한다 | 실행해서 통과하면 `통과`, 실행할 수 없으면 `미실행: 이유`. 이유를 사용자에게 한 줄로 말한다 |
| `TL;DR`, `Summary` 같은 영어 소제목 | 템플릿 소제목을 그대로 쓴다 |
| 커밋 메시지를 그대로 나열한다 | "이번에 한 일"에 바뀐 것을 사용자 관점으로 요약한다. 커밋 목록은 넣지 않는다 |
