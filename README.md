# TokenManager

## 📌 Visão Geral

O **TokenManager** é um sistema simples de gerenciamento de tokens temporários com limite de uso e controle de concorrência. Ele expõe uma API para registro, consulta e liberação de tokens, com persistência em banco de dados e liberação automática baseada em tempo de uso.

---

## ⚙️ Tecnologias Utilizadas

- **Elixir + Phoenix** – API REST
- **PostgreSQL** – Armazenamento dos tokens e histórico
- **Ecto** – ORM para persistência
- **GenServer supervisionado** – Gerenciamento de tokens ativos e lógica de expiração

---

## 🎯 Funcionalidades da API

A aplicação expõe endpoints para as seguintes operações:

- **Registrar o uso de um token**

  - Retorna: ID do token e ID do usuário

- **Listar todos os tokens**

  - Retorna: Tokens disponíveis e tokens em uso

- **Consultar um token específico**

  - Retorna: Informações do token, usuário atual (se houver) e histórico

- **Consultar histórico de utilização de um token**

  - Retorna: Lista de usuários que já utilizaram o token

- **Liberar todos os tokens ativos**

  - Retorna: Confirmação da liberação

---

## 🔁 Regras de Negócio

- O sistema possui um conjunto **fixo de 100 tokens**, todos representados por UUIDs.
- Um token pode estar em dois estados: **disponível** ou **ativo**.
- Cada token pode ser utilizado por **um único usuário por vez**.
- Quando um token é usado, ele se torna ativo por até **2 minutos**.
- Após 2 minutos, o token é **automaticamente liberado** e volta à lista de disponíveis.
- Caso o limite de **100 tokens ativos** seja atingido, o **token mais antigo em uso é liberado automaticamente** para permitir nova alocação.
- O sistema **não cria nem descarta tokens**, apenas alterna seu estado.

---

## ⏱️ Lógica de Liberação Automática

A liberação automática dos tokens ativos após 2 minutos é feita de forma robusta. Existem algumas abordagens implementadas:

- Agendamento individual por token usando `Process.send_after` para liberar após o tempo limite.
- Um processo supervisionado (GenServer) responsável por acompanhar os tokens ativos.
- Possibilidade de extensão com jobs periódicos para verificar expirados, caso desejado.

---

## ✅ Objetivo do Projeto

Esse projeto visa demonstrar a implementação de um **gerenciador de recursos com controle de concorrência e liberação automática**, aplicável em cenários como filas de execução, controle de sessões limitadas, ou recursos compartilhados. Foi construído com foco em clareza arquitetural e boas práticas em Elixir.
