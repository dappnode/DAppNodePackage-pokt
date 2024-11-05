export interface Account {
  amount: number;
  amountStaked: Number;
  address: string;
  network: String;
  node: any;
  jailed: Boolean;
  unstakingTime: Date;
  publicKey: String;
}

export interface Chain {
  id: string;
  name: String;
  url: String;
  state: number;
}
