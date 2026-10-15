# Sky Assinatura Digital

Projeto VCL escrito para Delphi 10.3 Rio e Delphi 12, Windows 10/11, Win32/Win64.
Os fontes foram criados sem compilacao, build ou execucao de testes, conforme solicitado.
A compatibilidade e o funcionamento precisam ser conferidos no seu Delphi.

## Abrir e utilizar

1. Abra `SkyAssinatura.dproj` no Delphi. Se a IDE solicitar conversao, salve a configuracao correspondente a sua versao. Tambem e possivel abrir o `.dpr` diretamente.
2. A tela esta em `src/Sky.Main.pas` e `src/Sky.Main.dfm`, com controles e eventos editaveis no designer. Abra a unit e use F12 para alternar entre codigo e formulario. Nao ha componentes para instalar. O formulario principal e registrado no projeto e `MainFormOnTaskbar` esta habilitado.
3. Mantenha a pasta `scripts` ao lado do executavel. A configuracao coloca o executavel na raiz do projeto.
4. Importe seu certificado A1 pelo assistente do Windows em **Usuario atual > Pessoal**, incluindo a chave privada. O aplicativo nao recebe nem grava a senha do PFX.
5. Para A3, instale o driver/provedor do fabricante. O Windows pode solicitar PIN durante a assinatura; compatibilidade depende do provedor e do suporte a SHA-256. Nao ha garantia para todos os tokens.
6. Abra um PDF, selecione o certificado, escolha a pagina e clique no local desejado. O clique representa o canto superior esquerdo; perto das bordas o bloco e ajustado para caber.
7. Informe largura e altura em pontos PDF (72 pontos = uma polegada). Depois de alterar o tamanho, clique novamente para posicionar.
8. Salve com um nome novo. O original nao e sobrescrito. Confira o documento em um leitor que valide assinaturas PDF.

## Ajustes de abertura e salvamento na IDE

O `.dproj` inclui `Delphi.Personality/Source/MainSource`, `ProjectFileVersion`, tipo `Application`, plataformas Win32/Win64 e registros Base/Debug/Release. A estrutura anterior estava incompleta para o gerenciamento do projeto pela IDE. A versao base de metadados foi mantida em 18.0 para Delphi 10.3; o Delphi 12 pode atualizar esses metadados ao salvar.

Depois de atualizar os arquivos, feche o projeto na IDE sem sobrescrever as alteracoes em disco e reabra o `.dproj`. O erro em `xmlrtl290.bpl` ocorre na IDE; a alteracao corrige a estrutura identificada no arquivo, mas sua resolucao nao foi confirmada por execucao. Nenhum arquivo local de preferencias/cache da IDE foi removido.

## Implementacao

- VCL/RTL do Delphi para interface e manipulacao de arquivos.
- Leitura de xref tradicional ou xref stream PDF 1.5+, e objetos compactados em ObjStm. Descompressao pela `System.ZLib` da RTL do Delphi, sem DLL externa adicional. Streams estruturais aceitam ausencia de filtro ou um filtro FlateDecode, com predictors TIFF/PNG de 8 bits.
- `cryptui.dll` para selecao no repositorio pessoal do Windows.
- `crypt32.dll`, `CryptSignMessage`, SHA-256 e CMS/PKCS#7 detached.
- Inclusao incremental de campo `/Sig`, widget com aparencia e `/ByteRange` no PDF. Os bytes originais permanecem no arquivo de saida.
- Formularios AcroForm existentes sao preservados: o novo campo e acrescentado a `/Fields`, mantendo os campos anteriores, recursos e demais propriedades. A lista `/Annots` da pagina tambem e preservada, inclusive quando indireta. As chaves alteradas sao substituidas, sem duplicar `/AcroForm`, `/Fields`, `/SigFlags` ou `/Annots`. O nome do novo campo inclui um GUID.
- Previa por `Windows.Data.Pdf`, acessado pelo Windows PowerShell 5.1 e WinRT; nao usa PDFium, Adobe Reader, ACBr, OpenSSL ou pacotes externos.
- O script local usa `ExecutionPolicy Bypass` apenas no processo iniciado. Politicas corporativas podem impedir a execucao; nesse caso a mensagem de erro sera exibida.
- A previa usa uma copia temporaria exclusiva do documento aberto. Os arquivos temporarios sao removidos no encerramento normal; uma interrupcao forcada pode deixa-los na pasta temporaria do usuario.
- Renderizacao e assinatura sao sincronas; a janela pode aguardar durante essas operacoes.

## Escopo e limites desta versao

Este e um projeto inicial de assinatura PDF nativa, com suporte intencionalmente restrito; nao e um motor completo de PDF nem uma implementacao certificada de PAdES/ICP-Brasil.

Aceita PDF com tabela xref tradicional ou xref stream, uma revisao e objetos em geracao zero, incluindo objetos compactados em ObjStm. Interpreta `/W`, `/Index` e entradas xref de tipos 0, 1 e 2. Kids, MediaBox e CropBox podem ser diretos ou indiretos; as caixas podem ser herdadas. O posicionamento considera a intersecao de CropBox e MediaBox. Preserva os conteudos das paginas sem reescrever seus streams.

Recusa na leitura PDF criptografado, xref hibrido, revisoes incrementais, UserUnit e paginas rotacionadas. Em streams estruturais, filtros diferentes de FlateDecode, multiplos filtros e predictors com componentes diferentes de 8 bits ainda sao recusados. Alguns PDFs comuns terao essas estruturas e serao recusados. O parser nao pretende cobrir todo o padrao PDF.

A presenca de `/AcroForm`, `/Annots` ou `/Perms` por si so nao impede abrir a previa. Ao assinar, formularios AcroForm comuns sao aceitos; XFA, assinatura existente, bloqueios `/Lock`, certificacao DocMDP, direitos de uso UR/UR3 e permissoes desconhecidas sao recusados com mensagens especificas. Esta versao acrescenta um campo novo; nao preenche um campo de assinatura ja existente nem altera/reutiliza assinaturas anteriores. Nao e um editor dos campos do formulario. As recusas de politicas reais permanecem porque o projeto ainda nao interpreta as alteracoes permitidas por elas.

Limite de entrada: 200 MB; reserva de CMS: 32 KB. O processamento usa varias copias em memoria; prefira documentos pequenos, especialmente em Win32. Nomes no bloco visual usam Helvetica ASCII; caracteres fora de ASCII sao substituidos por `?`.

A data do bloco vem do computador. Nao inclui carimbo de tempo confiavel, verificacao de revogacao/OCSP/CRL, validacao de cadeia, politica de assinatura ICP-Brasil, DSS/LTV ou garantia de conformidade PAdES. A selecao permite certificados que podem nao ter chave privada ou estar vencidos; o operador deve escolher o adequado e conferir a validacao externa. A confianca exibida por leitores depende da cadeia e das configuracoes do leitor.

O fluxo visual e semelhante ao de posicionamento de assinaturas, mas nao integra a conta nem o servico de assinatura gov.br.

## Arquivos

- `SkyAssinatura.dpr` / `.dproj`: entrada e configuracao do projeto.
- `src/Sky.Main.pas` / `.dfm`: janela editavel no designer, previa e coordenadas.
- `src/Sky.Crypto.pas`: selecao de certificado e CMS.
- `src/Sky.Pdf.pas`: leitura do perfil PDF suportado e assinatura incremental.
- `scripts/Render-Pdf.ps1`: renderizacao nativa de uma pagina em PNG.

## Referencias tecnicas

- https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/nf-wincrypt-cryptsignmessage
- https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/ns-wincrypt-crypt_sign_message_para
- https://learn.microsoft.com/en-us/windows/win32/api/cryptuiapi/nf-cryptuiapi-cryptuidlgselectcertificatefromstore
- https://learn.microsoft.com/en-us/uwp/api/windows.data.pdf.pdfdocument
- https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/PDF32000_2008.pdf (secoes 7.4, 7.5.7 e 7.5.8: filtros, ObjStm e xref streams)

Nenhum teste foi executado. Na sua avaliacao, confira primeiro uma pagina simples, posicionamento, integridade criptografica e cadeia do certificado em um leitor externo; depois avalie as recusas documentadas com seus PDFs reais.

## Licenca

Este projeto e distribuido sob a licenca [MIT](LICENSE).

Copyright (c) 2026 Janderson Silva. Perfil: [janderson-silva](https://github.com/janderson-silva).

Na configuracao Debug/Win32, Show general messages e Use MSBuild externally to compile estao explicitamente definidos como false. Os caminhos de saida e pesquisa continuam os definidos no projeto.
