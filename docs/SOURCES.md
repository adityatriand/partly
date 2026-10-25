# Job sources

Only sources listed here may be fetched. A page being public is not permission to collect it. This app does not bypass logins, CAPTCHAs, or rate limits, and it does not crawl arbitrary HTML.

Every feed below was reviewed on 2026-10-25. Listings that are not clearly remote and part-time are dropped. Descriptions are stored as plain text, capped at 4000 characters. Logos and raw HTML are not stored. Rows stay in the local SQLite file until the user deletes `~/Library/Application Support/Partly/`. Nothing is uploaded.

A failed source does not change that source's existing rows. A successful catalog with at least one eligible job marks this source's previously open rows that were absent as `missing`. They are not deleted. `closed` is set only when the user reports the listing as stale or filled.

One refresh calls every feed. The app refuses another refresh for 60 seconds. Background refresh is not implemented.

## Remotive

| | |
| :---- | :---- |
| Permission | [API documentation](https://remotive.com/api-documentation). Access is for sharing Remotive jobs. Link to the Remotive URL and name Remotive. Do not submit these jobs to other boards (Jooble, Neuvoo, Google Jobs, LinkedIn Jobs, and similar) |
| Access | `GET https://remotive.com/api/remote-jobs` |
| Rate limit | About 4 requests a day. More than 2 a minute is blocked |
| Remote evidence | The endpoint is a remote-job catalog, plus `candidate_required_location` |
| Part-time evidence | `job_type` contains part-time. Missing or other types are rejected |
| Closure | Empty or failed payload does not mark rows missing |

## Jobicy

| | |
| :---- | :---- |
| Permission | [Jobicy API v2](https://jobicy.com/api/v2/remote-jobs). The payload asks that Jobicy be credited with a direct link and that apply actions open the job URL from the feed |
| Access | `GET https://jobicy.com/api/v2/remote-jobs?count=50&tag=part-time` |
| Rate limit | One page per refresh. The tag query currently fits in one page |
| Remote evidence | The endpoint is a remote-job catalog, plus `jobGeo` |
| Part-time evidence | `jobType` contains part-time. The tag filter is fuzzy, so full-time rows in that response are still rejected |
| Closure | Same as the shared rule above |

## Remote OK

| | |
| :---- | :---- |
| Permission | [remoteok.com/api](https://remoteok.com/api). The legal field requires a link back to the Remote OK URL and the name Remote OK. Do not use the Remote OK logo |
| Access | `GET https://remoteok.com/api` |
| Rate limit | One request per refresh. The feed returns a short catalog |
| Remote evidence | The endpoint is a remote-job catalog, plus `location` when present |
| Part-time evidence | A `tags` value or the job title contains part-time. Other tags are rejected |
| Closure | Same as the shared rule above. The leading legal object is not a job |

## Arbeitnow

| | |
| :---- | :---- |
| Permission | [Job board API](https://www.arbeitnow.com/api/job-board-api). The payload says it is a free public API, asks for a link back, and says use is agreement to the Arbeitnow terms of service. Do not abuse it |
| Access | `GET https://www.arbeitnow.com/api/job-board-api` (first page only) |
| Rate limit | One page per refresh. Further pages are not requested |
| Remote evidence | `remote` must be true. On-site rows are rejected |
| Part-time evidence | `job_types` or the title contains part-time or Teilzeit |
| Closure | A page with no eligible rows does not mark older Arbeitnow rows missing |

## Himalayas

| | |
| :---- | :---- |
| Permission | [Remote Jobs API](https://himalayas.app/docs/remote-jobs-api). Show the jobs in this app, use `applicationLink` unchanged for apply, and name Himalayas with a link back. Do not pass the jobs on to other boards |
| Access | `GET https://himalayas.app/jobs/api/search?employment_type=Part%20Time` |
| Rate limit | One page (20 jobs) per refresh. Requests without a key share the public allowance. The feed is cached about 24 hours |
| Remote evidence | The endpoint is a remote-job catalog, plus `locationRestrictions` |
| Part-time evidence | `employmentType` is part-time. Other types are rejected |
| Closure | A page with no eligible rows does not mark older Himalayas rows missing |

## RemoteJobs.org

| | |
| :---- | :---- |
| Permission | [Remote Jobs API](https://remotejobs.org/developers/api). Free, no key. Show a visible link back to RemoteJobs.org and keep the job's application link intact |
| Access | `GET https://remotejobs.org/api/v1/jobs?type=part-time&limit=50` |
| Rate limit | One page per refresh. The API asks for fewer than 200 requests an hour per IP, shared with their v2 |
| Remote evidence | The endpoint is a remote-job catalog, plus `location` |
| Part-time evidence | `employment_types` or `type` contains part-time. The type filter is still re-checked |
| Closure | Same as the shared rule above |

Rows without part-time evidence, without remote evidence, or without an `https` URL are ignored.
