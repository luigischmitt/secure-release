# Secure Release — spec inicial

**Status:** rascunho para discussão, atualizado em 26/09/2026. Repositório público planejado e GitHub Pages escolhido como destino.

## Objetivo

Publicar uma aplicação web estática pequena no GitHub Pages somente depois de verificar criptograficamente o artifact gerado pelo pipeline. A entrega deve mostrar, na prática, a diferença entre conferir um hash e confiar na origem de um arquivo assinado.

## Contexto da disciplina

O enunciado do seminário pede uma equipe de duas pessoas, uma implementação prática de uma técnica ou ferramenta de criptografia e uma apresentação remota de 9 minutos em 30/09/2026. Ele sugere três partes: apresentação do problema (2 min), modelagem e conceitos (2,5 min) e demonstração (4,5 min). Essas divisões são uma sugestão do documento.

O capítulo 2 de Stallings fundamenta a escolha: a seção 2.2 apresenta hash e integridade; a 2.3, criptografia de chave pública; e a 2.4, assinatura digital e certificados. Para este projeto, o artifact pode permanecer público. A propriedade que buscamos é detectar alteração e verificar a procedência, não ocultar seu conteúdo.

## Escolha da técnica

| Técnica | O que demonstraria | Adequação ao projeto |
| --- | --- | --- |
| SHA-256 isolado | Mudança no conteúdo | Se alguém substitui o arquivo e o hash publicado junto, o receptor não sabe quem produziu ambos. |
| HMAC | Integridade e autenticação com segredo compartilhado | Exigiria distribuir e proteger o mesmo segredo nos lados de build e deploy. |
| Assinatura digital com atestação | Integridade e identidade verificável do produtor | Corresponde ao problema de release e permite associar o artifact a repositório, workflow e commit. |

O GitHub implementa a terceira opção com Sigstore e atestações de procedência. A verificação precisa conferir também a identidade esperada; uma assinatura matematicamente válida de outra origem não autoriza um deploy. O GitHub descreve atestações básicas como SLSA Build Level 2, sem que isso signifique que o artifact seja seguro para executar.

## Proposta de MVP

**Artifact:** um único pacote `site.tar.gz` contendo uma página `index.html` com uma versão visível. O site é o exemplo real de software publicado.

**Assinatura:** usar a atestação de artifact do GitHub Actions (`actions/attest`). Ela associa o SHA-256 do pacote à procedência do build e é assinada por uma identidade do workflow, sem gerenciar uma chave privada permanente no repositório.

**Destino:** GitHub Pages. A publicação consome apenas os arquivos extraídos do pacote que acabou de passar pela verificação.

**Site:** uma página HTML estática. Ela reduz o trabalho de frontend e mantém o pacote assinado como unidade de release. O Pages publicará o conteúdo extraído desse pacote depois da verificação.

**Fluxo:**

1. Uma execução de release iniciada na branch principal constrói `site.tar.gz`.
2. O job de build gera a atestação desse pacote e o envia como artifact da execução.
3. Um job separado baixa o pacote e chama `gh attestation verify` antes de extrair ou publicar qualquer conteúdo.
4. A verificação exige o repositório, o workflow assinante, o commit e a referência esperados para aquela execução. Falha ou ausência de atestação interrompe o job.
5. Depois da verificação, o job prepara os arquivos do site e faz o deploy no GitHub Pages. O job de build não recebe permissão para deploy.

O arquivo assinado é o pacote. O GitHub Pages cria seu próprio pacote de transporte a partir dos arquivos verificados; nenhuma etapa de build ou transformação de conteúdo ocorre depois da verificação.

## Modelo de confiança

- **Integridade:** alterar um byte do pacote muda seu hash e faz a verificação falhar.
- **Autenticidade/procedência:** a verificação aceita somente a identidade do workflow e a origem esperadas, além da assinatura válida.
- **Controle de publicação:** o passo de deploy fica após a verificação no job que possui a permissão de Pages.
- **Limite:** uma assinatura válida não prova que o código do site é benigno. A regra depende de proteger a branch principal e o workflow de build contra alterações não autorizadas.

## Critérios de aceitação

1. Um pacote produzido pelo workflow esperado passa pela verificação e chega ao Pages.
2. Uma cópia adulterada do mesmo pacote falha na verificação.
3. Um pacote sem atestação, ou atestado por uma origem diferente da política, não chega ao deploy.
4. Os logs tornam visíveis o hash do artifact, a origem verificada e o resultado do bloqueio.
5. A demonstração cabe em 4,5 minutos usando execuções preparadas de antemão e uma verificação feita ao vivo.

## Etapas de implementação e aprendizado

| Etapa | Conceito | O que vamos construir e comprovar |
| --- | --- | --- |
| 1. Modelo de ameaça | Qual arquivo é confiável e onde ele pode ser trocado | Desenhar o fluxo `build → artifact → verificação → deploy` e definir a política de origem. |
| 2. Artifact e hash | SHA-256 identifica bytes, mas não identifica sozinho o autor | Gerar o site, criar `site.tar.gz`, calcular seu hash e observar a mudança após adulterar uma cópia. |
| 3. Assinatura e procedência | Chave pública, certificado, identidade do workflow e commit | Atestar o pacote no Actions, verificar com `gh attestation verify` e inspecionar o resultado. |
| 4. Bloqueio do deploy | Verificação falha antes de liberar a publicação | Separar build e deploy em jobs, conceder a permissão de Pages apenas ao segundo e testar sucesso/falha. |
| 5. Publicação e apresentação | Evidência observável do controle | Abrir o site publicado, conferir o commit apresentado e ensaiar a demonstração. |

Em cada etapa, primeiro explicamos o conceito, depois implementamos uma parte pequena e por fim provocamos um caso de falha para entender o limite da proteção.

### Roteiro para 9 minutos

1. **0–2 min:** apresentar o risco de substituir um artifact depois do build e a diferença entre hash e assinatura.
2. **2–4,5 min:** mostrar o fluxo e explicar o que a verificação confere: bytes, assinatura e origem.
3. **4,5–9 min:** abrir o Pages, mostrar uma execução aprovada, verificar o pacote original ao vivo, adulterar uma cópia e mostrar a falha. Ter também uma execução de falha já preparada para mostrar que o deploy foi bloqueado, sem depender da duração do Actions durante a aula.

Depois do MVP, podemos estudar assinatura direta com Cosign, imagens de container, políticas de ambiente e outros metadados de cadeia de suprimentos.

## Plano de execução

O passo a passo de implementação, aprendizado e preparação da apresentação está em [PLAN.md](PLAN.md).

## Fontes

- Material do seminário fornecido pelo aluno, `seminario criptografia.pdf`.
- Stallings e Brown, *Segurança de Computadores*, capítulo 2: <https://www.kufunda.net/publicdocs/Seguran%C3%A7a%20de%20Computadores%20%28WILLIAM%20STALLINGS%29.pdf>.
- GitHub Docs, [Artifact attestations](https://docs.github.com/en/actions/concepts/security/artifact-attestations) e [Using artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations).
- GitHub CLI, [`gh attestation verify`](https://cli.github.com/manual/gh_attestation_verify).
- GitHub Docs, [Deploying your website automatically](https://docs.github.com/en/get-started/start-your-journey/deploying-your-website-automatically).
- GitHub Docs, [Configuring a publishing source for GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site).
