export interface Account {
  amount: number;
  amountStaked: Number;
  address: string;
  network: String;
  node: any;
//<<<<<<< Local/Devel/RC.0.12.0
  jailed: Boolean;
  unstakingTime: Date;
  publicKey: String;
//=======
//  jailed: boolean;
//  unstakingTime: Date;
//  publicKey: string;
//>>>>>>> Voss/devel
}

export interface Chain {
  id: string;
  name: String;
  url: String;
  state: number;
}
