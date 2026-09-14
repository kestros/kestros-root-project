# Licensing — which header goes on which file

**A module whose Java package root is `io.kestros.commons` carries the Kestros Apache 2.0
header and an Apache `LICENSE`. Every other Kestros module carries GPL v3 and a GPL
`LICENSE`. There are no per-module exceptions.**

The rule turns on the **package declaration in the file**, not on the repository name.
`kestros-common-utils` is named like a commons module and is not one on the old reading;
`kestros-user-api`, `kestros-user-core` and `kestros-user-foundation` are named like
commons modules and declare `io.kestros.cms` packages. Reading the package is what makes
the policy checkable without anybody keeping a list.

Decided by Danny on 2026-09-14, on card #1274.

## The ASF contributor wording is wrong on every Kestros file

123 files in the org open with:

> Licensed to the Apache Software Foundation (ASF) under one or more contributor license
> agreements ... The ASF licenses this file to you under the Apache License, Version 2.0

That is the header an Apache project puts on code contributed **to** the ASF. On
Kestros-owned code it reads as a copyright assignment to the ASF and names no Kestros
copyright at all. It is wrong wherever it appears — on the `io.kestros.commons` side as
much as on the `io.kestros.cms` side — and `check-licence-headers.sh` reports it as wrong
on both.

Use the Apache-2.0 appendix form below instead. It is the same licence; it names the
correct copyright holder.

## The two headers, verbatim

### `io.kestros.commons` — Apache 2.0

```java
/*
 * Copyright 2026 Kestros, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
```

### Everything else — GPL v3

```java
/*
 *      Copyright (C) 2020  Kestros, Inc.
 *
 *     This program is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     This program is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 */
```

The GPL text is reproduced exactly as the 348 files that already carry it have it,
including the `2020` year and the indentation — so that adding a header to a file never
introduces a second variant of the same header.

## The checker

```
kestros-build-tools/src/main/scripts/check-licence-headers.sh <dir-of-kestros-clones>
```

It reads every `src/main/**/*.java` file under each clone, classifies the leading comment
block, and reports any file whose header is the wrong licence for its own `package`
declaration. Exit 1 when it finds one, exit 0 when it does not.

Files with **no header at all** are reported in a separate section and do not affect the
exit code. There were 2,512 of those when this was written; adding them is the work of the
checkstyle and RAT cards and of #1018, not of this checker.

Self-test, which needs no clones:

```
bash kestros-build-tools/src/main/scripts/check-licence-headers.sh --self-test
```

### What the checker does not read

**Only `.java` files.** POM files, JavaScript, HTML and JSON are out of its reach. That
matters here because `kestros-build-tools/pom.xml` in this very repository carries the ASF
contributor wording, and the checker will never say so. Correcting non-Java files is
tracked separately.

### It is deliberately not wired into the build

No `pom.xml` and no Jenkins job calls this script. Four modules are on the wrong side of
the policy line today and 123 files carry the ASF wording, so enforcing it in the build
before those are corrected would fail every build in the org. Wiring it in is a follow-up
once the repositories conform.
