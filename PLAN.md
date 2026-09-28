# Plano de execução — Secure Release

**Estado:** em execução. Vamos implementar em etapas, discutindo o conceito e observando uma prova prática antes de avançar. O repositório está público e o seminário está marcado para 30/09/2026.

## Resultado que queremos alcançar

Uma página `index.html` simples será empacotada como `site.tar.gz`. O GitHub Actions criará uma atestação assinada para esse pacote. Um segundo job verificará os bytes e a origem da atestação antes de publicar o conteúdo no GitHub Pages. Se a verificação falhar, o site publicado deverá permanecer na versão anterior.

Usaremos GitHub Pages. A página terá uma versão visível para que o resultado do deploy, ou de seu bloqueio, seja fácil de mostrar. O arquivo HTML é apenas a aplicação de exemplo; o objeto que o pipeline assina e verifica é o pacote completo.

## Como vamos trabalhar juntos

Em cada etapa faremos quatro movimentos: entender o conceito, implementar a menor parte útil, observar um caso de sucesso e provocar uma falha controlada. Antes de passar à etapa seguinte, você deve conseguir explicar com suas palavras o que foi protegido, por quem e contra qual alteração.

## Etapa 1 — Definir a ameaça e a regra de confiança

**Aprendizado:** distinguir integridade, autenticidade e confidencialidade. Identificar o instante em que um artifact sai do build e entra no deploy.

- [x] Desenhar o fluxo: código-fonte → pacote → atestação → verificação → Pages.
- [x] Definir o adversário de demonstração: alguém substitui ou altera o pacote entre o build e a publicação.
- [x] Registrar a política: aceitar somente o pacote cujo hash corresponda a uma atestação válida do repositório, workflow, referência e commit esperados.
- [x] Registrar o limite: um pacote assinado pode conter código ruim se o código-fonte ou o workflow autorizado forem comprometidos.

**Concluída quando:** conseguimos explicar por que o job de deploy precisa verificar o pacote que ele próprio recebeu, mesmo depois de um build bem-sucedido.

**Situação:** concluída em 26/09/2026. O fluxo, a ameaça, a política e o limite estão registrados em [SPEC.md](SPEC.md); a explicação do motivo da verificação no deploy foi consolidada.

## Etapa 2 — Criar a aplicação mínima e seu artifact

**Aprendizado:** diferenciar arquivo-fonte, saída de build e unidade de release. O artifact precisa ter bytes definidos antes da assinatura.

- [x] Criar uma página HTML pequena, com título do projeto e uma versão visível.
- [x] Organizar uma saída de publicação que contenha apenas os arquivos do site.
- [x] Empacotar essa saída em `site.tar.gz` e conferir o que há dentro do pacote.
- [x] Documentar qual versão da página corresponde ao pacote criado.

**Concluída quando:** conseguimos abrir a página localmente e identificar sem ambiguidade qual arquivo será assinado e publicado.

**Situação:** concluída em 26/09/2026. Você confirmou a aparência da página `0.1.0`; `site.tar.gz` contém apenas `index.html`.

## Etapa 3 — Fazer o experimento com hash

**Aprendizado:** SHA-256 funciona como identificação do conteúdo. Ele detecta mudança nos bytes, mas um hash entregue junto com um arquivo por uma origem não confiável não prova quem criou os dois.

- [x] Calcular e registrar o SHA-256 do pacote original.
- [x] Alterar uma cópia do pacote e confirmar que seu SHA-256 mudou.
- [x] Simular a troca simultânea do arquivo e do hash publicado para entender a limitação de usar apenas checksum.
- [x] Relacionar o experimento às seções 2.2 e 2.4 do livro: hash, assinatura e autenticação da origem.

**Concluída quando:** você consegue responder: “Por que o hash sozinho detecta alteração, mas não autoriza um deploy?”

**Situação:** concluída em 26/09/2026. O experimento e os valores estão registrados em [SPEC.md](SPEC.md); a etapa seguinte foi iniciada a seu pedido.

## Etapa 4 — Atestar o pacote no GitHub Actions

**Aprendizado:** uma assinatura vincula o hash a uma identidade verificável. No caso do GitHub, a atestação também informa a procedência do build.

- [x] Criar a execução manual de release na branch principal.
- [x] No job de build, produzir exatamente o pacote definido na etapa 2.
- [x] Dar ao job somente as permissões necessárias para ler o código e gerar a atestação.
- [x] Gerar a atestação com a ferramenta oficial do GitHub e disponibilizar o pacote para o job seguinte.
- [x] Inspecionar o resultado: hash do pacote, repositório, workflow e commit associados à atestação.

**Concluída quando:** uma execução do Actions produz um pacote e sua atestação, e conseguimos explicar de onde vem a identidade do assinante.

**Situação:** concluída em 28/09/2026. A execução [36476423665](https://github.com/luigischmitt/secure-release/actions/runs/36476423665) produziu `site.tar.gz` e sua atestação. O SHA-256 foi `07b0a52435b49ec8a8d46582b1baadef0dc72ae4813d6a828760ac7b816e344d`, ligado ao repositório `luigischmitt/secure-release`, workflow `.github/workflows/release.yml`, referência `refs/heads/main` e commit `b6fe2d3f2cbad8e0e87b833691b94bcf8c1441d1`. A verificação com `gh attestation verify` confirmou a identidade OIDC do workflow e o registro de transparência do Sigstore.

## Etapa 5 — Criar a barreira de verificação

**Aprendizado:** a assinatura só protege a publicação se o lado que publica exigir a verificação e aplicar uma política de origem.

- [x] Criar um segundo job que baixa o pacote recebido do job de build.
- [x] Verificar o pacote antes de extrair ou enviar qualquer conteúdo ao Pages.
- [x] Exigir correspondência com o repositório, workflow, referência e commit da execução autorizada.
- [ ] Demonstrar que qualquer falha de verificação encerra o fluxo antes da publicação.
- [x] Conceder a permissão de Pages somente ao job responsável pela publicação.
- [x] Conferir quem pode alterar a branch principal e o workflow, pois essa é a raiz de confiança do projeto.

**Concluída quando:** um pacote válido passa, e o passo de publicação não é alcançado quando a verificação falha.

**Situação:** a barreira está no próprio job `deploy`: ele baixa o artifact e exige assinatura, hash, repositório, workflow, referência e commit corretos antes de extrair o pacote. Só esse job recebe `pages: write` e `id-token: write`. A inspeção de 28/09/2026 encontrou somente o proprietário com permissão de escrita, mas nenhuma proteção de branch ou ruleset para `main`; recomendamos ativar proteção por PR como ação administrativa fora do código. A demonstração de falha controlada será feita na etapa 7.

## Etapa 6 — Publicar no GitHub Pages

**Aprendizado:** um deploy é uma ação separada do build; a autorização de publicar deve vir depois da verificação.

- [x] Configurar o workflow para publicar via GitHub Actions.
- [x] No job de deploy, verificar o pacote recebido antes de extrair o único arquivo regular `index.html` e enviá-lo ao Pages.
- [ ] Publicar a primeira versão e abrir o endereço do site.
- [ ] Confirmar que a versão exibida corresponde à execução aprovada.

**Concluída quando:** o site está acessível e é possível rastrear sua versão até o pacote e a execução que passaram na verificação.

**Situação:** workflow implementado em `.github/workflows/release.yml`. A publicação roda no mesmo job que baixa e verifica o pacote; só esse job tem `pages: write` e `id-token: write`. A primeira execução depende da PR ser incorporada e do Pages usar GitHub Actions como fonte.

## Etapa 7 — Testar as decisões de segurança

**Aprendizado:** uma demonstração de segurança precisa mostrar tanto a aprovação quanto a rejeição, com efeito observável sobre o deploy.

- [ ] Testar o pacote original: verificação aprovada e publicação permitida.
- [ ] Testar uma cópia adulterada após a assinatura: verificação rejeitada e publicação bloqueada.
- [ ] Testar pacote sem atestação ou procedência fora da política: publicação bloqueada.
- [ ] Conferir nos logs a razão de cada resultado.
- [ ] Confirmar que, após uma tentativa rejeitada, o Pages ainda mostra a última versão aprovada.

**Situação:** o workflow oferece quatro opções manuais: `normal`, `tampered-package`, `without-attestation` e `wrong-provenance`. Os três cenários negativos foram configurados para falhar na verificação antes de extrair ou publicar. A evidência em Actions e a conferência de que a página não mudou serão registradas depois que as PRs forem incorporadas e o Pages estiver configurado.

**Concluída quando:** temos evidência clara dos três resultados e nenhuma execução rejeitada altera o site.

## Etapa 8 — Documentar e ensaiar o seminário

**Aprendizado:** explicar o que a criptografia realmente garante, a política aplicada e seus limites.

- [x] Escrever um README curto com problema, fluxo, técnica escolhida e forma de repetir os testes.
- [ ] Guardar links das execuções aprovada e rejeitada e do site publicado.
- [x] Preparar um diagrama simples e poucos slides com hash, assinatura, identidade e barreira de deploy.
- [ ] Ensaiar a demonstração ao vivo usando um pacote original e uma cópia adulterada.
- [ ] Cronometrar e ajustar a apresentação para 9 minutos.

**Situação:** `README.md` e o deck de 5 slides `seminario/secure-release-apresentacao-v2.pptx` foram preparados. Os links do Pages e dos testes integrados dependem da incorporação das PRs e das execuções finais. O ensaio e a cronometragem ainda precisam ser feitos pela dupla.

**Roteiro sugerido:** 2 minutos para o problema; 2,5 minutos para o modelo; 4,5 minutos para mostrar o Pages, a execução aprovada, a verificação ao vivo e a execução rejeitada. Deixaremos as execuções do Actions prontas antes da aula para não depender do tempo de build durante a apresentação.

**Divisão possível para a dupla:** uma pessoa apresenta o problema, o hash e o artifact; a outra explica a assinatura, a política de verificação e o pipeline. As duas participam da demonstração e devem conseguir responder perguntas sobre todo o fluxo.

## Critério de término do MVP

O projeto está pronto para o seminário quando um pacote legítimo publica uma versão identificável no Pages, um pacote alterado é bloqueado antes do deploy, os logs mostram por que cada decisão ocorreu e a dupla consegue explicar o resultado dentro dos 9 minutos.

Depois da apresentação, podemos aprofundar o estudo com assinatura direta via Cosign, imagens de container, políticas de ambiente e outros metadados de cadeia de suprimentos.
