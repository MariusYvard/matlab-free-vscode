function D=distance_points(A,B)
if nargin==1,B=A;end
nA=size(A,1);nB=size(B,1);
D=sqrt(max(0,sum(A.^2,2)*ones(1,nB)+ones(nA,1)*sum(B.^2,2)'-2*(A*B')));
end
